# Claude Agent Orchestrator - Enhanced Multi-Agent System

## 🚀 What's New

This enhanced version of the Tmux-Orchestrator adds specialized agents and makes the system project-agnostic for easy deployment across any codebase.

### New Agent Types
- **PRD Agent** - Converts vague ideas into detailed specifications
- **UX/UI Expert** - Handles design, user experience, and frontend aesthetics
- **Supabase Agent** - Database expert, manages Supabase configurations
- **QA/Tester Agent** - Automated testing and quality assurance
- **Code Reviewer Agent** - Code quality and security reviews
- **Documentation Agent** - Maintains docs and API references

### Enhanced Scripts
- `spawn-agent.sh` - Generic agent spawner with role selection
- `setup-project.sh` - One-command project initialization
- `agent-registry.sh` - Track and manage active agents
- `health-check.sh` - Monitor agent status and performance
- `orchestrator-init.sh` - Initialize orchestrator with configuration

## 📋 Quick Start

### 1. Initialize the Orchestrator
```bash
cd Claude-Agent-Orchestrator
./scripts/orchestrator-init.sh
```

This will:
- Create an orchestrator session
- Set up monitoring windows
- Configure check-in intervals

### 2. Start a New Project
```bash
./scripts/setup-project.sh my-app /path/to/project medium
```

This automatically:
- Creates a tmux session for your project
- Spawns a PRD Agent to create specifications
- Deploys a Project Manager
- Sets up the appropriate team size

### 3. Monitor Your Agents
```bash
# View all active agents
./scripts/agent-registry.sh list

# Check agent health
./scripts/health-check.sh

# Continuous monitoring
./scripts/health-check.sh --continuous
```

## 🏗️ Project Structure

```
Claude-Agent-Orchestrator/
├── agents/
│   ├── templates/        # Agent role definitions
│   │   ├── orchestrator.md
│   │   ├── prd_agent.md
│   │   ├── project_manager.md
│   │   ├── engineer.md
│   │   ├── ux_ui_expert.md
│   │   ├── supabase_expert.md
│   │   ├── qa_tester.md
│   │   ├── code_reviewer.md
│   │   └── documentation.md
│   ├── configs/         # Agent configurations
│   └── registry/        # Active agent tracking
├── scripts/
│   ├── spawn-agent.sh
│   ├── setup-project.sh
│   ├── agent-registry.sh
│   ├── health-check.sh
│   └── orchestrator-init.sh
├── send-claude-message.sh
├── schedule_with_note.sh
└── tmux_utils.py
```

## 🎯 Usage Examples

### Starting with a Vague Idea
```bash
# 1. Setup project
./scripts/setup-project.sh todo-app ~/projects/todo-app

# 2. Tell the PRD Agent your idea
./send-claude-message.sh todo-app:1 "I want to build a todo app that syncs across devices and has a clean, modern UI"

# 3. The PRD Agent will ask clarifying questions and create a detailed spec
# 4. The Project Manager takes over and deploys the team
# 5. Engineers start implementing based on the PRD
```

### Spawn a Specific Agent
```bash
# Add a UX expert to an existing project
./scripts/spawn-agent.sh my-project 8 ux_ui_expert /path/to/project

# Add a database specialist
./scripts/spawn-agent.sh my-project 9 supabase_expert /path/to/project
```

### Communicate with Agents
```bash
# Ask for status
./send-claude-message.sh project:2 "STATUS UPDATE: What's your progress?"

# Assign a task
./send-claude-message.sh project:3 "TASK: Implement user authentication using JWT"

# Request code review
./send-claude-message.sh project:7 "Please review the auth implementation in feature/auth branch"
```

## 🔧 Configuration

### Orchestrator Configuration
Create `orchestrator-config.yaml`:
```yaml
project:
  name: "My Project"
  type: "auto-detect"

orchestrator:
  schedule_interval: 60  # minutes
  
agents:
  project_manager:
    quality_threshold: "high"
    commit_interval: 30
    
  engineers:
    default_count: 2
    specializations: ["frontend", "backend"]
```

### Team Sizes
- **Small**: 1 PM + 1 Engineer
- **Medium**: 1 PM + 2 Engineers + 1 QA
- **Large**: 1 PM + 3 Engineers + 1 QA + 1 Reviewer
- **Enterprise**: Full team with all specialists

## 📊 Monitoring & Health

### Health Check Output
```
═══════════════════════════════════════════════════════
Health Check: my-project
Time: 2024-01-30 10:30:45
═══════════════════════════════════════════════════════

Session: my-project
────────────────────────────────
  Window 0: Orchestrator - ✓ Active
    Interactions: Human: 5, Assistant: 12
    Last: Checking project progress...
  
  Window 2: PM - ✓ Active
    Interactions: Human: 8, Assistant: 15
    Git activity: 3 commands
    Last: Assigned authentication task to Engineer-1...
    
  Window 3: Engineer-1 - ⏳ Waiting
    Interactions: Human: 10, Assistant: 18
    ⚠️  Warning: No git activity detected (remember 30-min commits!)

Summary:
  Active agents: 2/3
  Warnings: 1
  Health Score: 67%
```

### Agent Registry
```bash
# List all agents
./scripts/agent-registry.sh list

# Find specific agents
./scripts/agent-registry.sh find role engineer
./scripts/agent-registry.sh find session my-project

# Generate report
./scripts/agent-registry.sh report
```

## 🎨 Agent Specializations

### PRD Agent
- Converts ideas to specifications
- Asks clarifying questions
- Creates acceptance criteria
- Defines success metrics

### Project Manager
- Enforces quality standards
- Manages git discipline
- Coordinates team members
- Tracks progress

### Engineers
- Frontend: React, UI implementation
- Backend: APIs, databases
- Full-stack: End-to-end features
- DevOps: Infrastructure, CI/CD

### QA/Tester
- Writes automated tests
- Performance testing
- Security scanning
- Bug tracking

### Code Reviewer
- Security audits
- Performance optimization
- Best practices enforcement
- Technical debt tracking

## 🚨 Best Practices

### Git Discipline
All agents follow strict git practices:
- Commit every 30 minutes
- Feature branches for all work
- Meaningful commit messages
- Tag stable versions

### Communication
- Use STATUS UPDATE for progress checks
- Use TASK for assignments
- Use BLOCKER for issues
- Keep messages concise

### Quality Standards
- Minimum 80% test coverage
- All code reviewed before merge
- Documentation updated with code
- Security scans on every PR

## 🔄 Workflow Example

```
1. Human: "I need a user dashboard"
   ↓
2. Orchestrator: Deploys PRD Agent
   ↓
3. PRD Agent: Creates detailed specification
   ↓
4. Orchestrator: Reviews PRD, deploys team
   ↓
5. PM: Assigns tasks to engineers
   ↓
6. Engineers: Implement features
   ↓
7. QA: Tests implementation
   ↓
8. Reviewer: Ensures quality
   ↓
9. PM: Reports completion
```

## 🛠️ Troubleshooting

### Agent Not Responding
```bash
# Check if agent is alive
./scripts/health-check.sh quick session:window

# Send wake-up message
./send-claude-message.sh session:window "Status update?"

# Restart agent if needed
tmux kill-window -t session:window
./scripts/spawn-agent.sh session window role /path
```

### Performance Issues
```bash
# Check system load
./scripts/health-check.sh --continuous

# Reduce agent count
./scripts/agent-registry.sh cleanup

# Adjust check-in intervals
```

## 📚 Advanced Usage

### Custom Agent Types
1. Create template in `agents/templates/`
2. Add to `agent_registry.json`
3. Use `spawn-agent.sh` to deploy

### Automation
```bash
# Schedule project setup
echo "0 9 * * 1-5 /path/to/setup-project.sh daily-tasks /projects/daily" | crontab -e

# Auto-scale based on load
./scripts/orchestrator-init.sh auto-scale-config.yaml
```

## 🎯 Next Steps

1. **Test with Your Project**: Try the system on a real project
2. **Customize Agents**: Modify templates for your needs
3. **Share Feedback**: Report issues and improvements
4. **Contribute**: Add new agent types or enhancements

## 📄 License

MIT License - Use freely but wisely. With great automation comes great responsibility.