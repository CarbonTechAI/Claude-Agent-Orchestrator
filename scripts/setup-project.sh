#!/bin/bash

# setup-project.sh - One-command project initialization with multi-agent team
# Usage: ./setup-project.sh <project_name> <project_path> [team_size]

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SPAWN_SCRIPT="$SCRIPT_DIR/spawn-agent.sh"

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to display usage
usage() {
    echo "Usage: $0 <project_name> <project_path> [team_size]"
    echo ""
    echo "Arguments:"
    echo "  project_name - Name for the tmux session and project"
    echo "  project_path - Path to the project directory"
    echo "  team_size    - Optional: small, medium, large (defaults to auto-detect)"
    echo ""
    echo "Team sizes:"
    echo "  small  - 1 PM + 1 Engineer"
    echo "  medium - 1 PM + 2 Engineers + 1 QA"
    echo "  large  - 1 PM + 3 Engineers + 1 QA + 1 Reviewer"
    echo ""
    echo "Example:"
    echo "  $0 my-app /home/user/projects/my-app medium"
    exit 1
}

# Check arguments
if [ $# -lt 2 ]; then
    usage
fi

PROJECT_NAME=$1
PROJECT_PATH=$2
TEAM_SIZE=${3:-"auto"}

# Validate project path
if [ ! -d "$PROJECT_PATH" ]; then
    print_color "$RED" "Error: Project path '$PROJECT_PATH' does not exist"
    exit 1
fi

# Auto-detect team size based on project complexity
detect_team_size() {
    local path=$1
    local file_count=$(find "$path" -type f -name "*.js" -o -name "*.ts" -o -name "*.py" -o -name "*.java" 2>/dev/null | wc -l)
    
    if [ $file_count -lt 50 ]; then
        echo "small"
    elif [ $file_count -lt 200 ]; then
        echo "medium"
    else
        echo "large"
    fi
}

# Auto-detect if needed
if [ "$TEAM_SIZE" = "auto" ]; then
    TEAM_SIZE=$(detect_team_size "$PROJECT_PATH")
    print_color "$YELLOW" "Auto-detected team size: $TEAM_SIZE"
fi

# Check if session already exists
if tmux has-session -t "$PROJECT_NAME" 2>/dev/null; then
    print_color "$RED" "Error: Session '$PROJECT_NAME' already exists"
    echo "Kill it with: tmux kill-session -t $PROJECT_NAME"
    exit 1
fi

print_color "$BLUE" "═══════════════════════════════════════════════════════"
print_color "$BLUE" "Setting up project: $PROJECT_NAME"
print_color "$BLUE" "Path: $PROJECT_PATH"
print_color "$BLUE" "Team size: $TEAM_SIZE"
print_color "$BLUE" "═══════════════════════════════════════════════════════"

# Create tmux session
print_color "$GREEN" "Creating tmux session..."
tmux new-session -d -s "$PROJECT_NAME" -c "$PROJECT_PATH"

# Window 0: Orchestrator
print_color "$YELLOW" "Setting up Orchestrator..."
tmux rename-window -t "$PROJECT_NAME:0" "Orchestrator"
"$SPAWN_SCRIPT" "$PROJECT_NAME" "0" "orchestrator" "$PROJECT_PATH"
sleep 5

# Window 1: PRD Agent (temporary - will close after PRD is created)
print_color "$YELLOW" "Setting up PRD Agent..."
tmux new-window -t "$PROJECT_NAME:1" -n "PRD-Agent" -c "$PROJECT_PATH"
"$SPAWN_SCRIPT" "$PROJECT_NAME" "1" "prd_agent" "$PROJECT_PATH"
sleep 5

# Window 2: Project Manager
print_color "$YELLOW" "Setting up Project Manager..."
tmux new-window -t "$PROJECT_NAME:2" -n "PM" -c "$PROJECT_PATH"
"$SPAWN_SCRIPT" "$PROJECT_NAME" "2" "project_manager" "$PROJECT_PATH"
sleep 3

# Set up team based on size
case $TEAM_SIZE in
    small)
        # Window 3: Engineer
        print_color "$YELLOW" "Setting up Engineer..."
        tmux new-window -t "$PROJECT_NAME:3" -n "Engineer" -c "$PROJECT_PATH"
        "$SPAWN_SCRIPT" "$PROJECT_NAME" "3" "engineer" "$PROJECT_PATH"
        ;;
    
    medium)
        # Window 3-4: Engineers
        for i in 3 4; do
            print_color "$YELLOW" "Setting up Engineer $((i-2))..."
            tmux new-window -t "$PROJECT_NAME:$i" -n "Engineer-$((i-2))" -c "$PROJECT_PATH"
            "$SPAWN_SCRIPT" "$PROJECT_NAME" "$i" "engineer" "$PROJECT_PATH"
            sleep 2
        done
        
        # Window 5: QA
        print_color "$YELLOW" "Setting up QA/Tester..."
        tmux new-window -t "$PROJECT_NAME:5" -n "QA" -c "$PROJECT_PATH"
        "$SPAWN_SCRIPT" "$PROJECT_NAME" "5" "qa_tester" "$PROJECT_PATH"
        ;;
    
    large)
        # Window 3-5: Engineers
        for i in 3 4 5; do
            print_color "$YELLOW" "Setting up Engineer $((i-2))..."
            tmux new-window -t "$PROJECT_NAME:$i" -n "Engineer-$((i-2))" -c "$PROJECT_PATH"
            "$SPAWN_SCRIPT" "$PROJECT_NAME" "$i" "engineer" "$PROJECT_PATH"
            sleep 2
        done
        
        # Window 6: QA
        print_color "$YELLOW" "Setting up QA/Tester..."
        tmux new-window -t "$PROJECT_NAME:6" -n "QA" -c "$PROJECT_PATH"
        "$SPAWN_SCRIPT" "$PROJECT_NAME" "6" "qa_tester" "$PROJECT_PATH"
        
        # Window 7: Code Reviewer
        print_color "$YELLOW" "Setting up Code Reviewer..."
        tmux new-window -t "$PROJECT_NAME:7" -n "Reviewer" -c "$PROJECT_PATH"
        "$SPAWN_SCRIPT" "$PROJECT_NAME" "7" "code_reviewer" "$PROJECT_PATH"
        ;;
esac

# Create utility windows
print_color "$YELLOW" "Creating utility windows..."

# Shell window
tmux new-window -t "$PROJECT_NAME" -n "Shell" -c "$PROJECT_PATH"

# Dev server window
tmux new-window -t "$PROJECT_NAME" -n "Dev-Server" -c "$PROJECT_PATH"

# Git window
tmux new-window -t "$PROJECT_NAME" -n "Git" -c "$PROJECT_PATH"

# Create project configuration
CONFIG_DIR="$PROJECT_PATH/.claude-orchestrator"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/project.json" << EOF
{
  "project_name": "$PROJECT_NAME",
  "project_path": "$PROJECT_PATH",
  "team_size": "$TEAM_SIZE",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "session_name": "$PROJECT_NAME",
  "agents": {
    "orchestrator": { "window": 0, "status": "active" },
    "prd_agent": { "window": 1, "status": "temporary" },
    "project_manager": { "window": 2, "status": "active" }
  }
}
EOF

# Initial orchestrator briefing
print_color "$MAGENTA" "Sending initial project briefing to Orchestrator..."
INITIAL_BRIEFING="Project '$PROJECT_NAME' has been initialized with a $TEAM_SIZE team.

Project path: $PROJECT_PATH

Your team is ready in the following windows:
- Window 1: PRD Agent (temporary - for initial specification)
- Window 2: Project Manager
$(case $TEAM_SIZE in
    small) echo "- Window 3: Engineer";;
    medium) echo "- Windows 3-4: Engineers
- Window 5: QA/Tester";;
    large) echo "- Windows 3-5: Engineers
- Window 6: QA/Tester
- Window 7: Code Reviewer";;
esac)

Utility windows:
- Shell: For command line operations
- Dev-Server: For running development servers
- Git: For version control operations

Please start by working with the PRD Agent in window 1 to create a detailed specification for this project. Once the PRD is complete, brief the Project Manager and let them coordinate the team.

Use the schedule_with_note.sh script to set up regular check-ins."

if [ -f "$SCRIPT_DIR/../send-claude-message.sh" ]; then
    "$SCRIPT_DIR/../send-claude-message.sh" "$PROJECT_NAME:0" "$INITIAL_BRIEFING"
else
    tmux send-keys -t "$PROJECT_NAME:0" "$INITIAL_BRIEFING"
    sleep 0.5
    tmux send-keys -t "$PROJECT_NAME:0" Enter
fi

print_color "$GREEN" "═══════════════════════════════════════════════════════"
print_color "$GREEN" "✓ Project setup complete!"
print_color "$GREEN" "═══════════════════════════════════════════════════════"
echo ""
print_color "$BLUE" "To attach to the orchestrator:"
print_color "$YELLOW" "  tmux attach-session -t $PROJECT_NAME"
echo ""
print_color "$BLUE" "To see all windows:"
print_color "$YELLOW" "  tmux list-windows -t $PROJECT_NAME"
echo ""
print_color "$BLUE" "To send a message to any agent:"
print_color "$YELLOW" "  ./send-claude-message.sh $PROJECT_NAME:<window> \"Your message\""
echo ""
print_color "$MAGENTA" "The Orchestrator is now ready to receive your project requirements!"