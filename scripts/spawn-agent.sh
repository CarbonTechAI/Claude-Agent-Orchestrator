#!/bin/bash

# spawn-agent.sh - Generic agent spawner with role selection
# Usage: ./spawn-agent.sh <session> <window> <role> [project_path]

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TEMPLATE_DIR="$SCRIPT_DIR/../agents/templates"

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to display usage
usage() {
    echo "Usage: $0 <session> <window> <role> [project_path]"
    echo ""
    echo "Arguments:"
    echo "  session      - Tmux session name"
    echo "  window       - Window number or name"
    echo "  role         - Agent role (orchestrator, prd_agent, project_manager, engineer, etc.)"
    echo "  project_path - Optional: Path to project directory (defaults to current directory)"
    echo ""
    echo "Available roles:"
    ls -1 "$TEMPLATE_DIR" | sed 's/\.md$//' | sed 's/^/  - /'
    exit 1
}

# Check arguments
if [ $# -lt 3 ]; then
    usage
fi

SESSION=$1
WINDOW=$2
ROLE=$3
PROJECT_PATH=${4:-$(pwd)}

# Validate role
TEMPLATE_FILE="$TEMPLATE_DIR/${ROLE}.md"
if [ ! -f "$TEMPLATE_FILE" ]; then
    print_color "$RED" "Error: Template not found for role '$ROLE'"
    echo "Available roles:"
    ls -1 "$TEMPLATE_DIR" | sed 's/\.md$//' | sed 's/^/  - /'
    exit 1
fi

# Check if session exists
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    print_color "$RED" "Error: Session '$SESSION' does not exist"
    echo "Create it with: tmux new-session -s $SESSION"
    exit 1
fi

# Check if window exists, create if not
if ! tmux list-windows -t "$SESSION" | grep -q "^$WINDOW:"; then
    print_color "$YELLOW" "Window $WINDOW does not exist, creating..."
    tmux new-window -t "$SESSION:$WINDOW" -n "$ROLE" -c "$PROJECT_PATH"
fi

# Function to wait for Claude to be ready
wait_for_claude() {
    local target=$1
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        # Check if Claude is responsive
        local pane_content=$(tmux capture-pane -t "$target" -p | tail -20)
        if echo "$pane_content" | grep -q "Assistant:"; then
            return 0
        fi
        sleep 1
        ((attempt++))
    done
    
    return 1
}

# Start Claude in the window
print_color "$BLUE" "Starting Claude in $SESSION:$WINDOW..."
tmux send-keys -t "$SESSION:$WINDOW" "claude" Enter

# Wait for Claude to start
if ! wait_for_claude "$SESSION:$WINDOW"; then
    print_color "$RED" "Error: Claude did not start properly"
    exit 1
fi

print_color "$GREEN" "Claude started successfully"

# Read the template content
TEMPLATE_CONTENT=$(cat "$TEMPLATE_FILE")

# Prepare the briefing message
BRIEFING="You are being deployed as a $ROLE agent.

Your working directory is: $PROJECT_PATH

Please read and internalize the following role definition and instructions:

$TEMPLATE_CONTENT

Once you understand your role, please acknowledge and provide a brief summary of your responsibilities."

# Send the briefing to Claude
print_color "$BLUE" "Sending role briefing to agent..."
# Use the send-claude-message.sh script if available
if [ -f "$SCRIPT_DIR/../send-claude-message.sh" ]; then
    "$SCRIPT_DIR/../send-claude-message.sh" "$SESSION:$WINDOW" "$BRIEFING"
else
    # Fallback to direct tmux commands
    tmux send-keys -t "$SESSION:$WINDOW" "$BRIEFING"
    sleep 0.5
    tmux send-keys -t "$SESSION:$WINDOW" Enter
fi

# Give agent time to process the briefing
sleep 3

# Check agent acknowledgment
print_color "$GREEN" "Agent spawned successfully!"
print_color "$YELLOW" "Checking agent status..."
tmux capture-pane -t "$SESSION:$WINDOW" -p | tail -30

# Log the agent creation
LOG_FILE="$SCRIPT_DIR/../agents/registry/spawn.log"
mkdir -p "$(dirname "$LOG_FILE")"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Spawned $ROLE agent in $SESSION:$WINDOW at $PROJECT_PATH" >> "$LOG_FILE"

print_color "$GREEN" "✓ Agent deployment complete!"
print_color "$BLUE" "You can interact with the agent at: $SESSION:$WINDOW"
print_color "$BLUE" "To send messages: ./send-claude-message.sh $SESSION:$WINDOW \"Your message\""