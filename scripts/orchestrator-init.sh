#!/bin/bash

# orchestrator-init.sh - Initialize orchestrator with configuration
# Usage: ./orchestrator-init.sh [config_file]

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DEFAULT_CONFIG="$ROOT_DIR/orchestrator-config.yaml"

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to display usage
usage() {
    echo "Usage: $0 [config_file]"
    echo ""
    echo "Initialize an orchestrator with optional configuration file."
    echo "If no config file is provided, uses interactive setup."
    echo ""
    echo "Config file format (YAML):"
    echo "  project:"
    echo "    name: 'My Project'"
    echo "    type: 'auto-detect'  # or nodejs, python, etc."
    echo "  agents:"
    echo "    orchestrator:"
    echo "      schedule_interval: 60  # minutes"
    echo "    project_manager:"
    echo "      quality_threshold: 'high'"
    echo "    engineers:"
    echo "      count: 2"
    echo "      specializations: ['frontend', 'backend']"
    exit 1
}

# Parse arguments
CONFIG_FILE=""
if [ $# -gt 0 ]; then
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        usage
    fi
    CONFIG_FILE=$1
fi

# Function to create default config
create_default_config() {
    cat > "$DEFAULT_CONFIG" << 'EOF'
# Orchestrator Configuration
project:
  name: "AI Development Team"
  type: "auto-detect"
  description: "Multi-agent development orchestration"

orchestrator:
  schedule_interval: 60  # Check-in interval in minutes
  max_concurrent_projects: 3
  
agents:
  project_manager:
    quality_threshold: "high"  # high, medium, balanced
    enforce_testing: true
    enforce_documentation: true
    commit_interval: 30  # minutes
    
  engineers:
    default_count: 2
    max_count: 5
    specializations:
      - frontend
      - backend
      - fullstack
      - devops
      
  qa_tester:
    test_coverage_minimum: 80
    run_security_scans: true
    
  code_reviewer:
    auto_review: true
    security_focus: high
    
  deployment:
    auto_schedule: true
    work_hours: "9-17"  # Local time
    
monitoring:
  health_check_interval: 15  # minutes
  alert_on_idle: 30  # minutes
  log_retention_days: 30
  
communication:
  status_report_interval: 240  # minutes (4 hours)
  use_hub_spoke_model: true
  max_message_length: 1000
EOF
}

# Function for interactive setup
interactive_setup() {
    print_color "$BLUE" "═══════════════════════════════════════════════════════"
    print_color "$BLUE" "Orchestrator Interactive Setup"
    print_color "$BLUE" "═══════════════════════════════════════════════════════"
    
    # Session name
    read -p "Enter orchestrator session name [ai-orchestrator]: " session_name
    session_name=${session_name:-"ai-orchestrator"}
    
    # Check if session exists
    if tmux has-session -t "$session_name" 2>/dev/null; then
        print_color "$RED" "Session '$session_name' already exists!"
        read -p "Kill existing session? (y/n): " kill_session
        if [ "$kill_session" = "y" ]; then
            tmux kill-session -t "$session_name"
        else
            exit 1
        fi
    fi
    
    # Schedule interval
    read -p "Check-in interval in minutes [60]: " schedule_interval
    schedule_interval=${schedule_interval:-60}
    
    # Quality standards
    echo ""
    print_color "$YELLOW" "Quality Standards:"
    echo "1. High - No compromises, extensive testing"
    echo "2. Balanced - Good quality with pragmatic trade-offs"
    echo "3. Rapid - Focus on speed, minimum viable quality"
    read -p "Select quality standard [1]: " quality_choice
    
    case $quality_choice in
        2) quality_standard="balanced";;
        3) quality_standard="rapid";;
        *) quality_standard="high";;
    esac
    
    # Team size preference
    echo ""
    read -p "Default team size (small/medium/large) [medium]: " team_size
    team_size=${team_size:-"medium"}
    
    # Create session
    print_color "$GREEN" "\nCreating orchestrator session..."
    tmux new-session -d -s "$session_name"
    
    # Start orchestrator
    print_color "$YELLOW" "Starting orchestrator agent..."
    "$SCRIPT_DIR/spawn-agent.sh" "$session_name" "0" "orchestrator" "$ROOT_DIR"
    
    # Wait for orchestrator to start
    sleep 5
    
    # Send configuration
    local config_message="You have been initialized with the following configuration:

Session: $session_name
Check-in Interval: $schedule_interval minutes
Quality Standard: $quality_standard
Default Team Size: $team_size

Your responsibilities:
1. Monitor all active projects across sessions
2. Deploy appropriate agent teams for new projects
3. Ensure quality standards are maintained
4. Schedule regular check-ins every $schedule_interval minutes
5. Coordinate cross-project dependencies

Available commands:
- Use spawn-agent.sh to create new agents
- Use send-claude-message.sh for agent communication
- Use health-check.sh to monitor agent status
- Use agent-registry.sh to track all agents

Please acknowledge this configuration and schedule your first check-in."

    "$ROOT_DIR/send-claude-message.sh" "$session_name:0" "$config_message"
    
    # Create management windows
    print_color "$YELLOW" "Creating management windows..."
    tmux new-window -t "$session_name:1" -n "Health-Monitor"
    tmux new-window -t "$session_name:2" -n "Agent-Registry"
    tmux new-window -t "$session_name:3" -n "Logs"
    
    # Set up health monitoring
    tmux send-keys -t "$session_name:1" "$SCRIPT_DIR/health-check.sh --continuous" Enter
    
    # Success message
    print_color "$GREEN" "═══════════════════════════════════════════════════════"
    print_color "$GREEN" "✓ Orchestrator initialized successfully!"
    print_color "$GREEN" "═══════════════════════════════════════════════════════"
    echo ""
    print_color "$BLUE" "To attach to orchestrator:"
    print_color "$YELLOW" "  tmux attach-session -t $session_name"
    echo ""
    print_color "$BLUE" "Windows:"
    print_color "$NC" "  0: Orchestrator (main agent)"
    print_color "$NC" "  1: Health Monitor (continuous monitoring)"
    print_color "$NC" "  2: Agent Registry (for manual checks)"
    print_color "$NC" "  3: Logs (for debugging)"
}

# Function to initialize from config file
init_from_config() {
    local config_file=$1
    
    if [ ! -f "$config_file" ]; then
        print_color "$RED" "Config file not found: $config_file"
        exit 1
    fi
    
    print_color "$BLUE" "Initializing from config: $config_file"
    
    # Parse YAML (simple parsing, would need yq for proper parsing)
    local project_name=$(grep "name:" "$config_file" | head -1 | cut -d: -f2 | tr -d " '\"")
    local schedule_interval=$(grep "schedule_interval:" "$config_file" | head -1 | cut -d: -f2 | tr -d " ")
    local quality=$(grep "quality_threshold:" "$config_file" | head -1 | cut -d: -f2 | tr -d " '\"")
    
    # Use defaults if not found
    project_name=${project_name:-"ai-orchestrator"}
    schedule_interval=${schedule_interval:-60}
    quality=${quality:-"high"}
    
    # Create session
    if tmux has-session -t "$project_name" 2>/dev/null; then
        print_color "$RED" "Session already exists: $project_name"
        exit 1
    fi
    
    tmux new-session -d -s "$project_name"
    
    # Copy config to project directory
    cp "$config_file" "$ROOT_DIR/.orchestrator-config.yaml"
    
    # Start orchestrator with config
    "$SCRIPT_DIR/spawn-agent.sh" "$project_name" "0" "orchestrator" "$ROOT_DIR"
    
    sleep 5
    
    # Send config to orchestrator
    local config_content=$(cat "$config_file")
    "$ROOT_DIR/send-claude-message.sh" "$project_name:0" "You have been initialized with this configuration:

$config_content

Please parse this configuration and set up your monitoring accordingly."
    
    print_color "$GREEN" "✓ Orchestrator initialized from config"
}

# Main execution
print_color "$MAGENTA" "Claude Agent Orchestrator Initialization"
print_color "$MAGENTA" "========================================"

if [ -n "$CONFIG_FILE" ]; then
    init_from_config "$CONFIG_FILE"
else
    # Check for default config
    if [ -f "$DEFAULT_CONFIG" ]; then
        print_color "$YELLOW" "Found default config at: $DEFAULT_CONFIG"
        read -p "Use this config? (y/n) [y]: " use_default
        if [ "${use_default:-y}" = "y" ]; then
            init_from_config "$DEFAULT_CONFIG"
        else
            interactive_setup
        fi
    else
        # Create default config for future use
        print_color "$YELLOW" "No config found. Creating default config..."
        create_default_config
        print_color "$GREEN" "Default config created at: $DEFAULT_CONFIG"
        echo ""
        interactive_setup
    fi
fi

# Create quick commands
QUICK_COMMANDS="$ROOT_DIR/quick-commands.sh"
cat > "$QUICK_COMMANDS" << 'EOF'
#!/bin/bash
# Quick commands for orchestrator management

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Orchestrator Quick Commands:${NC}"
echo ""
echo "1. View all agents:        ./scripts/agent-registry.sh list"
echo "2. Health check:           ./scripts/health-check.sh"
echo "3. Continuous monitoring:  ./scripts/health-check.sh --continuous"
echo "4. Spawn new agent:        ./scripts/spawn-agent.sh <session> <window> <role>"
echo "5. Setup new project:      ./scripts/setup-project.sh <name> <path>"
echo "6. Send message:           ./send-claude-message.sh <session:window> \"message\""
echo ""
echo -e "${YELLOW}Tmux commands:${NC}"
echo "Attach to orchestrator:    tmux attach-session -t ai-orchestrator"
echo "List all sessions:         tmux list-sessions"
echo "Switch windows:            Ctrl+b [number]"
echo "Detach from session:       Ctrl+b d"
EOF

chmod +x "$QUICK_COMMANDS"

print_color "$BLUE" "\nQuick reference created at: ./quick-commands.sh"