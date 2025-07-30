#!/bin/bash

# agent-registry.sh - Track and manage active agents across all sessions
# Usage: ./agent-registry.sh [command] [options]

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REGISTRY_DIR="$SCRIPT_DIR/../agents/registry"
REGISTRY_FILE="$REGISTRY_DIR/agents.json"

# Ensure registry directory exists
mkdir -p "$REGISTRY_DIR"

# Initialize registry file if it doesn't exist
if [ ! -f "$REGISTRY_FILE" ]; then
    echo '{"agents": [], "sessions": {}}' > "$REGISTRY_FILE"
fi

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to display usage
usage() {
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  list          - List all active agents"
    echo "  add           - Add an agent to registry"
    echo "  remove        - Remove an agent from registry"
    echo "  status        - Check status of all agents"
    echo "  find          - Find agents by role or session"
    echo "  report        - Generate detailed report"
    echo "  cleanup       - Remove inactive agents"
    echo ""
    echo "Examples:"
    echo "  $0 list"
    echo "  $0 add session:window role"
    echo "  $0 find role engineer"
    echo "  $0 status"
    exit 1
}

# Function to check if agent is alive
is_agent_alive() {
    local session=$1
    local window=$2
    
    # Check if session exists
    if ! tmux has-session -t "$session" 2>/dev/null; then
        return 1
    fi
    
    # Check if window exists
    if ! tmux list-windows -t "$session" | grep -q "^$window:"; then
        return 1
    fi
    
    # Check if Claude is running in the window
    local content=$(tmux capture-pane -t "$session:$window" -p 2>/dev/null | tail -5)
    if echo "$content" | grep -q "Assistant:\|Human:"; then
        return 0
    fi
    
    return 1
}

# List all agents
list_agents() {
    print_color "$BLUE" "═══════════════════════════════════════════════════════"
    print_color "$BLUE" "Active AI Agents"
    print_color "$BLUE" "═══════════════════════════════════════════════════════"
    
    local count=0
    
    # Parse tmux sessions and windows
    while IFS= read -r session; do
        [ -z "$session" ] && continue
        
        # Get windows in session
        while IFS= read -r window_info; do
            [ -z "$window_info" ] && continue
            
            # Extract window number and name
            local window_num=$(echo "$window_info" | cut -d: -f1)
            local window_name=$(echo "$window_info" | cut -d' ' -f2)
            
            # Check if it's likely an agent window
            if is_agent_alive "$session" "$window_num"; then
                ((count++))
                
                # Determine role from window name
                local role="unknown"
                case "$window_name" in
                    *Orchestrator*) role="orchestrator";;
                    *PM*|*Project*Manager*) role="project_manager";;
                    *Engineer*) role="engineer";;
                    *QA*|*Test*) role="qa_tester";;
                    *Review*) role="code_reviewer";;
                    *PRD*) role="prd_agent";;
                    *UX*|*UI*) role="ux_ui_expert";;
                    *Supabase*|*DB*) role="supabase_expert";;
                    *Doc*) role="documentation";;
                esac
                
                print_color "$GREEN" "  [$count] $session:$window_num ($window_name)"
                print_color "$CYAN" "       Role: $role"
                
                # Get last activity
                local last_line=$(tmux capture-pane -t "$session:$window_num" -p | grep -v "^$" | tail -1)
                if [ -n "$last_line" ]; then
                    print_color "$YELLOW" "       Last: ${last_line:0:60}..."
                fi
                echo ""
            fi
        done < <(tmux list-windows -t "$session" -F "#{window_index} #{window_name}" 2>/dev/null)
    done < <(tmux list-sessions -F "#{session_name}" 2>/dev/null)
    
    if [ $count -eq 0 ]; then
        print_color "$YELLOW" "No active agents found."
    else
        print_color "$BLUE" "Total active agents: $count"
    fi
    print_color "$BLUE" "═══════════════════════════════════════════════════════"
}

# Add agent to registry
add_agent() {
    if [ $# -lt 2 ]; then
        echo "Usage: $0 add <session:window> <role>"
        exit 1
    fi
    
    local target=$1
    local role=$2
    local session=$(echo "$target" | cut -d: -f1)
    local window=$(echo "$target" | cut -d: -f2)
    
    # Verify agent exists
    if ! is_agent_alive "$session" "$window"; then
        print_color "$RED" "Error: No active agent found at $target"
        exit 1
    fi
    
    # Add to registry using jq
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Create entry
    jq --arg session "$session" \
       --arg window "$window" \
       --arg role "$role" \
       --arg timestamp "$timestamp" \
       '.agents += [{
           "session": $session,
           "window": $window,
           "role": $role,
           "created_at": $timestamp,
           "status": "active"
       }]' "$REGISTRY_FILE" > "$REGISTRY_FILE.tmp" && mv "$REGISTRY_FILE.tmp" "$REGISTRY_FILE"
    
    print_color "$GREEN" "✓ Agent added to registry: $target ($role)"
}

# Find agents by criteria
find_agents() {
    if [ $# -lt 2 ]; then
        echo "Usage: $0 find <type> <value>"
        echo "Types: role, session"
        exit 1
    fi
    
    local search_type=$1
    local search_value=$2
    
    print_color "$BLUE" "Searching for agents..."
    
    case "$search_type" in
        role)
            # Find all agents with matching role
            local found=0
            while IFS= read -r session; do
                [ -z "$session" ] && continue
                
                while IFS= read -r window_info; do
                    [ -z "$window_info" ] && continue
                    
                    local window_num=$(echo "$window_info" | cut -d: -f1)
                    local window_name=$(echo "$window_info" | cut -d' ' -f2)
                    
                    if is_agent_alive "$session" "$window_num"; then
                        # Check if role matches
                        if echo "$window_name" | grep -qi "$search_value"; then
                            ((found++))
                            print_color "$GREEN" "Found: $session:$window_num ($window_name)"
                        fi
                    fi
                done < <(tmux list-windows -t "$session" -F "#{window_index} #{window_name}" 2>/dev/null)
            done < <(tmux list-sessions -F "#{session_name}" 2>/dev/null)
            
            if [ $found -eq 0 ]; then
                print_color "$YELLOW" "No agents found with role: $search_value"
            fi
            ;;
            
        session)
            # Find all agents in session
            if ! tmux has-session -t "$search_value" 2>/dev/null; then
                print_color "$RED" "Session not found: $search_value"
                exit 1
            fi
            
            while IFS= read -r window_info; do
                [ -z "$window_info" ] && continue
                
                local window_num=$(echo "$window_info" | cut -d: -f1)
                local window_name=$(echo "$window_info" | cut -d' ' -f2)
                
                if is_agent_alive "$search_value" "$window_num"; then
                    print_color "$GREEN" "Found: $search_value:$window_num ($window_name)"
                fi
            done < <(tmux list-windows -t "$search_value" -F "#{window_index} #{window_name}" 2>/dev/null)
            ;;
            
        *)
            print_color "$RED" "Unknown search type: $search_type"
            exit 1
            ;;
    esac
}

# Check status of all agents
check_status() {
    print_color "$BLUE" "Checking agent status..."
    echo ""
    
    local active=0
    local inactive=0
    
    # Check all tmux sessions
    while IFS= read -r session; do
        [ -z "$session" ] && continue
        
        local session_agents=0
        
        while IFS= read -r window_info; do
            [ -z "$window_info" ] && continue
            
            local window_num=$(echo "$window_info" | cut -d: -f1)
            local window_name=$(echo "$window_info" | cut -d' ' -f2)
            
            if is_agent_alive "$session" "$window_num"; then
                ((active++))
                ((session_agents++))
            fi
        done < <(tmux list-windows -t "$session" -F "#{window_index} #{window_name}" 2>/dev/null)
        
        if [ $session_agents -gt 0 ]; then
            print_color "$GREEN" "Session: $session - $session_agents active agents"
        fi
    done < <(tmux list-sessions -F "#{session_name}" 2>/dev/null)
    
    echo ""
    print_color "$CYAN" "Summary:"
    print_color "$GREEN" "  Active agents: $active"
    print_color "$YELLOW" "  Inactive agents: $inactive"
}

# Generate detailed report
generate_report() {
    local report_file="$REGISTRY_DIR/report_$(date +%Y%m%d_%H%M%S).md"
    
    {
        echo "# Agent Status Report"
        echo "Generated: $(date)"
        echo ""
        echo "## Active Sessions"
        
        while IFS= read -r session; do
            [ -z "$session" ] && continue
            
            echo ""
            echo "### Session: $session"
            echo ""
            
            local has_agents=false
            
            while IFS= read -r window_info; do
                [ -z "$window_info" ] && continue
                
                local window_num=$(echo "$window_info" | cut -d: -f1)
                local window_name=$(echo "$window_info" | cut -d' ' -f2)
                
                if is_agent_alive "$session" "$window_num"; then
                    has_agents=true
                    echo "- **Window $window_num**: $window_name"
                    
                    # Get some context
                    local context=$(tmux capture-pane -t "$session:$window_num" -p | grep -v "^$" | tail -3)
                    if [ -n "$context" ]; then
                        echo "  - Recent activity:"
                        echo "$context" | sed 's/^/    /'
                    fi
                fi
            done < <(tmux list-windows -t "$session" -F "#{window_index} #{window_name}" 2>/dev/null)
            
            if [ "$has_agents" = false ]; then
                echo "- No active agents"
            fi
        done < <(tmux list-sessions -F "#{session_name}" 2>/dev/null)
        
        echo ""
        echo "## Statistics"
        echo ""
        echo "- Total tmux sessions: $(tmux list-sessions 2>/dev/null | wc -l)"
        echo "- Sessions with agents: $(tmux list-sessions 2>/dev/null | while read s; do tmux list-windows -t "$(echo $s | cut -d: -f1)" 2>/dev/null; done | grep -E "Orchestrator|Engineer|PM|QA" | wc -l)"
        
    } > "$report_file"
    
    print_color "$GREEN" "✓ Report generated: $report_file"
}

# Cleanup inactive agents
cleanup_registry() {
    print_color "$YELLOW" "Cleaning up inactive agents..."
    
    local cleaned=0
    
    # This would normally update the JSON registry
    # For now, we'll just report what would be cleaned
    
    while IFS= read -r session; do
        [ -z "$session" ] && continue
        
        while IFS= read -r window_info; do
            [ -z "$window_info" ] && continue
            
            local window_num=$(echo "$window_info" | cut -d: -f1)
            
            if ! is_agent_alive "$session" "$window_num"; then
                print_color "$YELLOW" "Would clean: $session:$window_num"
                ((cleaned++))
            fi
        done < <(tmux list-windows -t "$session" -F "#{window_index} #{window_name}" 2>/dev/null)
    done < <(tmux list-sessions -F "#{session_name}" 2>/dev/null)
    
    if [ $cleaned -gt 0 ]; then
        print_color "$GREEN" "Would clean $cleaned inactive entries"
    else
        print_color "$GREEN" "Registry is clean - no inactive agents"
    fi
}

# Main command handler
case "${1:-list}" in
    list)
        list_agents
        ;;
    add)
        shift
        add_agent "$@"
        ;;
    remove)
        print_color "$YELLOW" "Remove functionality not yet implemented"
        ;;
    status)
        check_status
        ;;
    find)
        shift
        find_agents "$@"
        ;;
    report)
        generate_report
        ;;
    cleanup)
        cleanup_registry
        ;;
    *)
        usage
        ;;
esac