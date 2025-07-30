#!/bin/bash

# health-check.sh - Monitor agent status and performance
# Usage: ./health-check.sh [session] [--continuous]

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG_DIR="$SCRIPT_DIR/../agents/registry/logs"
METRICS_FILE="$LOG_DIR/metrics.json"

# Ensure directories exist
mkdir -p "$LOG_DIR"

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to display usage
usage() {
    echo "Usage: $0 [session] [--continuous]"
    echo ""
    echo "Options:"
    echo "  session      - Specific session to monitor (default: all)"
    echo "  --continuous - Run continuous monitoring"
    echo ""
    echo "Examples:"
    echo "  $0                    # Check all sessions once"
    echo "  $0 my-project         # Check specific session"
    echo "  $0 --continuous       # Monitor all sessions continuously"
    echo "  $0 my-project --continuous  # Monitor specific session"
    exit 1
}

# Parse arguments
SESSION_FILTER=""
CONTINUOUS=false

for arg in "$@"; do
    case $arg in
        --continuous|-c)
            CONTINUOUS=true
            ;;
        --help|-h)
            usage
            ;;
        *)
            SESSION_FILTER=$arg
            ;;
    esac
done

# Function to get agent activity metrics
get_agent_metrics() {
    local session=$1
    local window=$2
    
    # Capture recent activity
    local content=$(tmux capture-pane -t "$session:$window" -p -S -1000 2>/dev/null)
    
    # Calculate metrics
    local total_lines=$(echo "$content" | wc -l)
    local human_lines=$(echo "$content" | grep -c "^Human:" || echo "0")
    local assistant_lines=$(echo "$content" | grep -c "^Assistant:" || echo "0")
    local last_activity=$(echo "$content" | grep -E "^(Human|Assistant):" | tail -1)
    local last_timestamp=$(date +%s)
    
    # Check if agent is responsive
    local is_responsive="unknown"
    if echo "$content" | tail -20 | grep -q "Assistant:"; then
        is_responsive="yes"
    elif echo "$content" | tail -20 | grep -q "Human:"; then
        is_responsive="waiting"
    else
        is_responsive="no"
    fi
    
    echo "$total_lines|$human_lines|$assistant_lines|$is_responsive|$last_activity"
}

# Function to check git activity
check_git_activity() {
    local session=$1
    local window=$2
    
    # Look for git commands in recent history
    local git_commands=$(tmux capture-pane -t "$session:$window" -p -S -500 2>/dev/null | grep -c "git " || echo "0")
    local last_commit=$(tmux capture-pane -t "$session:$window" -p -S -500 2>/dev/null | grep "git commit" | tail -1)
    
    echo "$git_commands|$last_commit"
}

# Function to display health status
display_health() {
    local session=$1
    
    print_color "$BLUE" "═══════════════════════════════════════════════════════"
    print_color "$BLUE" "Health Check: ${session:-All Sessions}"
    print_color "$BLUE" "Time: $(date '+%Y-%m-%d %H:%M:%S')"
    print_color "$BLUE" "═══════════════════════════════════════════════════════"
    
    local total_agents=0
    local responsive_agents=0
    local inactive_agents=0
    local warnings=0
    
    # Get sessions to check
    local sessions_to_check=""
    if [ -n "$session" ]; then
        if tmux has-session -t "$session" 2>/dev/null; then
            sessions_to_check="$session"
        else
            print_color "$RED" "Session not found: $session"
            return 1
        fi
    else
        sessions_to_check=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)
    fi
    
    # Check each session
    while IFS= read -r sess; do
        [ -z "$sess" ] && continue
        
        local session_has_agents=false
        
        print_color "$CYAN" "\nSession: $sess"
        print_color "$CYAN" "────────────────────────────────"
        
        # Check each window
        while IFS= read -r window_info; do
            [ -z "$window_info" ] && continue
            
            local window_num=$(echo "$window_info" | awk '{print $1}' | tr -d ':')
            local window_name=$(echo "$window_info" | cut -d' ' -f2-)
            
            # Skip non-agent windows
            if ! echo "$window_name" | grep -qE "Orchestrator|PM|Engineer|QA|Review|PRD|UX|Supabase|Doc"; then
                continue
            fi
            
            session_has_agents=true
            ((total_agents++))
            
            # Get metrics
            local metrics=$(get_agent_metrics "$sess" "$window_num")
            IFS='|' read -r total_lines human_lines assistant_lines is_responsive last_activity <<< "$metrics"
            
            # Get git activity
            local git_info=$(check_git_activity "$sess" "$window_num")
            IFS='|' read -r git_commands last_commit <<< "$git_info"
            
            # Determine status
            local status_color=$GREEN
            local status_text="✓ Active"
            
            if [ "$is_responsive" = "no" ]; then
                status_color=$RED
                status_text="✗ Inactive"
                ((inactive_agents++))
            elif [ "$is_responsive" = "waiting" ]; then
                status_color=$YELLOW
                status_text="⏳ Waiting"
            else
                ((responsive_agents++))
            fi
            
            # Display agent info
            print_color "$status_color" "  Window $window_num: $window_name - $status_text"
            
            # Show metrics
            if [ "$total_lines" -gt 0 ]; then
                print_color "$NC" "    Interactions: Human: $human_lines, Assistant: $assistant_lines"
                
                if [ "$git_commands" -gt 0 ]; then
                    print_color "$GREEN" "    Git activity: $git_commands commands"
                fi
                
                # Check for warnings
                if [ "$is_responsive" = "yes" ] && [ "$git_commands" -eq 0 ] && [ "$assistant_lines" -gt 10 ]; then
                    print_color "$YELLOW" "    ⚠️  Warning: No git activity detected (remember 30-min commits!)"
                    ((warnings++))
                fi
            fi
            
            # Show last activity snippet
            if [ -n "$last_activity" ]; then
                local snippet="${last_activity:0:60}..."
                print_color "$NC" "    Last: $snippet"
            fi
        done < <(tmux list-windows -t "$sess" -F "#{window_index} #{window_name}" 2>/dev/null)
        
        if [ "$session_has_agents" = false ]; then
            print_color "$YELLOW" "  No agents found in this session"
        fi
    done <<< "$sessions_to_check"
    
    # Summary
    echo ""
    print_color "$BLUE" "═══════════════════════════════════════════════════════"
    print_color "$CYAN" "Summary:"
    print_color "$GREEN" "  Active agents: $responsive_agents/$total_agents"
    
    if [ $inactive_agents -gt 0 ]; then
        print_color "$RED" "  Inactive agents: $inactive_agents"
    fi
    
    if [ $warnings -gt 0 ]; then
        print_color "$YELLOW" "  Warnings: $warnings"
    fi
    
    # Performance metrics
    if [ $total_agents -gt 0 ]; then
        local health_score=$((responsive_agents * 100 / total_agents))
        local score_color=$GREEN
        
        if [ $health_score -lt 50 ]; then
            score_color=$RED
        elif [ $health_score -lt 80 ]; then
            score_color=$YELLOW
        fi
        
        print_color "$score_color" "  Health Score: $health_score%"
    fi
    
    print_color "$BLUE" "═══════════════════════════════════════════════════════"
}

# Function for continuous monitoring
continuous_monitor() {
    local session=$1
    local interval=30  # seconds
    
    print_color "$MAGENTA" "Starting continuous monitoring (Ctrl+C to stop)..."
    print_color "$MAGENTA" "Refresh interval: ${interval}s"
    
    while true; do
        clear
        display_health "$session"
        
        # Log metrics
        local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        local metrics_entry="{\"timestamp\": \"$timestamp\", \"agents\": $total_agents, \"active\": $responsive_agents}"
        echo "$metrics_entry" >> "$METRICS_FILE"
        
        sleep $interval
    done
}

# Quick agent check
quick_check() {
    local target=$1
    if [ -z "$target" ]; then
        print_color "$RED" "Usage: $0 quick <session:window>"
        exit 1
    fi
    
    local session=$(echo "$target" | cut -d: -f1)
    local window=$(echo "$target" | cut -d: -f2)
    
    local metrics=$(get_agent_metrics "$session" "$window")
    IFS='|' read -r total_lines human_lines assistant_lines is_responsive last_activity <<< "$metrics"
    
    if [ "$is_responsive" = "yes" ]; then
        print_color "$GREEN" "✓ Agent is responsive"
    else
        print_color "$RED" "✗ Agent is not responsive"
    fi
}

# Main execution
if [ "$1" = "quick" ]; then
    shift
    quick_check "$@"
elif [ "$CONTINUOUS" = true ]; then
    continuous_monitor "$SESSION_FILTER"
else
    display_health "$SESSION_FILTER"
fi

# Generate recommendations
if [ $warnings -gt 0 ] || [ $inactive_agents -gt 0 ]; then
    echo ""
    print_color "$YELLOW" "Recommendations:"
    
    if [ $inactive_agents -gt 0 ]; then
        print_color "$NC" "  • Check inactive agents and restart if needed"
        print_color "$NC" "  • Use: ./send-claude-message.sh <session:window> \"Status update?\""
    fi
    
    if [ $warnings -gt 0 ]; then
        print_color "$NC" "  • Remind agents about 30-minute commit rule"
        print_color "$NC" "  • Check if agents are blocked and need assistance"
    fi
fi