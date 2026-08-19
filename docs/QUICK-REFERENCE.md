# Quick Reference: Best Practices

> One-page guide to Git workflow, Claude Code usage, and Docker optimization

---

## Git Workflow Best Practices

### ✅ DO: Use `git pull --rebase`
```bash
# Set up alias for convenience
git config --global alias.pr 'pull --rebase'

# Use it when your push is rejected
git pr
# or
git pull --rebase
```

**Why**: Maintains linear commit history, avoids messy merge commits

### ✅ DO: Handle rebase conflicts properly
```bash
# If conflicts occur during rebase, you can:

# Option 1: Abort and use regular merge
git rebase --abort
git pull  # Creates merge commit but easier to resolve

# Option 2: Fix conflicts during interactive rebase (advanced)
# [fix conflicts in files]
git add .
git rebase --continue
```

### ❌ DON'T: Use `git pull` alone
Avoid `git pull` by itself when remote is ahead - it creates unnecessary merge commits

---

## Claude Code: Essential Commands

### Bash Mode
```bash
# Run any bash command directly
"run npm install"
"check the logs in /var/log"
```

### Model Switching
```bash
/model opus    # Powerful, for complex tasks
/model sonnet  # Fast and efficient, for daily work
```

### Auto-Accept Mode
```bash
/auto-accept on   # Claude makes changes without prompting
/auto-accept off  # Review each change
```

### Interrupt Claude
Press `ESC` to interrupt and redirect Claude's actions

### Documentation
```bash
"Explore the app architecture and save it to ARCHITECTURE.md"
```

---

## Claude Code: Workflow by Level

### Level 1: Beginner

**Essential Setup**:
- Install Claude Code (local or remote)
- Create `claude.md` for project memory
- Use to-do lists for task tracking

**Basic Commands**:
```bash
"Create a to-do list for adding user authentication"
"Write end-to-end tests for the login flow"
"Debug this screenshot [attach image]"
```

**Best Practices**:
- Use markdown files for long prompts (reference with `@filename.md`)
- Let Claude generate and maintain `claude.md`
- Add tasks to message queue while Claude works

---

### Level 2: Intermediate

**Planning & Strategy**:
```bash
# Use planning mode
/plan "How should we implement payment processing?"

# Control thinking depth
"think about the best approach"
"think hard about edge cases"
"ultra think about security implications"
```

**Beyond Code**:
- Research: "Research Stripe API and create integration plan"
- Documents: "Generate PRD for notification system"
- Changelogs: "Update CHANGELOG.md with recent changes"

**GitHub Integration**:
- Install GitHub Actions integration
- Tag issues with `@claude` for automatic fixing
- Claude can review PRs

**Mindset Shift**:
- Think like a PM: Give context and constraints
- Verify at high level (app works, tests pass)
- Not line-by-line code review

---

### Level 3: Master

**Parallel Work**:
```bash
# Multiple plans simultaneously
/subagents parallel "Explore 3 approaches to caching"

# Multi-Claude with Git worktrees
git worktree add ../feature-a feature-a
git worktree add ../feature-b feature-b
# Run separate Claude instances in each
```

**Advanced Customization**:
```bash
# Custom slash commands
/custom-command create generate-api "Create REST API endpoint with tests and docs"

# Specialized subagents
/agents create security-reviewer "Review code for security issues"
/agents create ui-designer "Convert Figma designs to React components"
```

**MCP Servers**:
- Database MCP: Direct database queries
- Playwright MCP: Browser automation, visual debugging
- Figma MCP: Design to code conversion

---

## Docker: Binhex Standardization

### Standard Volume Structure
All containers follow consistent paths:
```yaml
volumes:
  - /host/path/appdata:/config    # Config files, databases, logs
  - /host/path/data:/data          # Application data, downloads
  - /host/path/media:/media        # Media files (movies, TV, music)
```

### Standard Environment Variables
```yaml
environment:
  # User/Group Management (prevents permission issues)
  - PUID=1000              # Your user ID: id -u
  - PGID=1000              # Your group ID: id -g
  - UMASK=002              # File permissions (002 = group writable)
  
  # System Configuration
  - TZ=America/New_York    # Timezone
  - DEBUG=false            # Enable debug logging
```

**UMASK Values:**
- `000` = 777/666 (most permissive)
- `002` = 775/664 (recommended - group writable)
- `022` = 755/644 (user only)

### Standard Logging
- **All logs**: `/config/supervisord.log`
- **View logs**: `docker exec [container] cat /config/supervisord.log`
- Supervisord manages all container processes

### Quick Setup
```bash
# Find your PUID/PGID
id -u    # Returns PUID (e.g., 1000)
id -g    # Returns PGID (e.g., 1000)

# Docker run with Binhex standards
docker run -d \
  --name MyApp \
  -v $(pwd)/config:/config \
  -v $(pwd)/data:/data \
  -e PUID=$(id -u) \
  -e PGID=$(id -g) \
  -e UMASK=002 \
  -e TZ=America/New_York \
  -p 8080:8080 \
  myimage

# Docker Compose
services:
  MyApp:
    volumes:
      - ./config:/config
      - ./data:/data
    environment:
      - PUID=1000
      - PGID=1000
      - UMASK=002
      - TZ=America/New_York
```

---

## Docker Optimization Checklist

### ✅ 1. Minimal Base Image
```dockerfile
# ✅ Good
FROM alpine:3.19
FROM gcr.io/distroless/nodejs

# ❌ Avoid
FROM ubuntu:latest
FROM node:latest
```

### ✅ 2. Layer Caching
```dockerfile
# ✅ Good - dependencies first (change less often)
COPY package*.json ./
RUN npm install
COPY . .

# ❌ Avoid - code copied before dependencies
COPY . .
RUN npm install
```

### ✅ 3. .dockerignore File
```
node_modules
.git
.env
*.log
coverage
dist
build
.DS_Store
```

### ✅ 4. Combined RUN Commands
```dockerfile
# ✅ Good - single layer, cleanup included
RUN apt-get update && \
    apt-get install -y curl && \
    rm -rf /var/lib/apt/lists/*

# ❌ Avoid - multiple layers, temp files persist
RUN apt-get update
RUN apt-get install -y curl
RUN rm -rf /var/lib/apt/lists/*
```

### ✅ 5. Multi-Stage Builds
```dockerfile
# Build stage
FROM node:18-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Production stage
FROM node:18-alpine
WORKDIR /app
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
CMD ["node", "dist/index.js"]
```

**Benefits**:
- Smaller final image (no build tools)
- Faster deployments
- Improved security (fewer packages)

---

## Testing Best Practices

### Test-Driven Development (TDD)
```bash
# With Claude Code
"Use TDD to implement user registration feature"
"Write tests first, then implement the function"
```

### Test Generation
```bash
"Write end-to-end tests for the checkout flow"
"Generate unit tests for the UserService class"
"Add integration tests for the API endpoints"
```

### Debugging with Tests
```bash
"Write a test that reproduces this bug"
"Add test coverage for edge cases"
```

---

## Common Claude Code Prompts

### Architecture & Planning
```
"Explain how the authentication system works"
"Create a technical design doc for [feature]"
"What's the best approach to implement [feature]?"
"think hard about the architecture before implementing"
```

### Code Generation
```
"Implement [feature] with tests"
"Refactor [component] to improve performance"
"Add error handling to [function]"
"Convert this JavaScript to TypeScript"
```

### Debugging
```
"Debug this error: [paste error]"
"Why is [feature] not working? Here's a screenshot"
"Add logging to help debug [issue]"
"Profile and optimize [slow function]"
```

### Documentation
```
"Generate API documentation for all endpoints"
"Create a README for this module"
"Update CHANGELOG.md with recent changes"
"Document the deployment process"
```

### Research
```
"Research best practices for [technology]"
"Compare [library A] vs [library B] for our use case"
"Find examples of [pattern] implementation"
```

---

## Project Organization

### Folder Structure
```
├── README.md              # Main project docs (root only)
├── CLAUDE.md              # Symlink to docs/CLAUDE.md
├── _resources/            # NOT in git - dev references
│   ├── Examples/          # Code samples, API responses
│   ├── Research/          # Research docs, comparisons
│   ├── Assets/            # Design files, mockups
│   └── Notes/             # Meeting notes, scratchpad
└── docs/                  # All other documentation
    ├── ARCHITECTURE.md    # Required - system design
    ├── CLAUDE.md          # Actual file location
    ├── API.md             # API documentation
    └── [other-docs].md    # Additional docs
```

### Documentation Rules
1. **README.md stays in root** - Main project overview only
2. **All other docs in `/docs`** - Keeps root clean
3. **ARCHITECTURE.md required** - Document system design from start
4. **CLAUDE.md in docs/** - Symlinked to root for auto-detection
5. **`_resources/` NOT in git** - Add to .gitignore

### Using `_resources/` Folder
**Purpose**: Development references for humans and AI

**What to Store**:
- Draft documentation
- Example code and templates
- API response samples
- Research notes
- Design mockups
- Meeting notes
- Claude prompt files

**Quick Commands**:
```bash
# Create _resources structure
mkdir -p _resources/{Examples,Research,Assets,Notes}

# Add to .gitignore
echo "_resources/" >> .gitignore

# Store example
curl https://api.example.com/endpoint > _resources/Examples/ApiResponse.json

# Claude can reference it
"Check the API example in _resources/Examples/ApiResponse.json"
```

### Creating ARCHITECTURE.md
```bash
# Create at project start
touch docs/ARCHITECTURE.md

# Ask Claude to help
"Create ARCHITECTURE.md documenting our system design, 
components, and key architectural decisions"
```

**Should Include**:
- System overview and component diagram
- Technology stack rationale
- Design patterns used
- Data flow
- Security architecture
- Scalability considerations

---

## Naming Conventions (PascalCase Standard)

### Code Naming
- **Files**: `PascalCase` (e.g., `UserService.js`, `PaymentController.py`)
- **Variables**: `PascalCase` (e.g., `UserData`, `ConfigOptions`)
- **Functions**: `PascalCase` (e.g., `GetUserById`, `ProcessPayment`)
- **Classes**: `PascalCase` (e.g., `UserManager`, `DatabaseConnection`)
- **Constants**: `UPPER_SNAKE_CASE` (e.g., `MAX_RETRIES`, `API_URL`)

### Environment Variables
Always use `UPPER_SNAKE_CASE`:
- `PUID`, `PGID`, `UMASK`, `TZ` (Binhex standards)
- `DATABASE_URL`, `API_KEY`, `SECRET_TOKEN`
- `DEBUG`, `LOG_LEVEL`, `NODE_ENV`

### Docker Names
- **Images**: `lowercase-with-dashes` (e.g., `my-app:latest`)
- **Containers**: `PascalCase` or `lowercase-with-dashes` (e.g., `MyApp` or `my-app`)
- **Volumes**: `lowercase_with_underscores` (e.g., `app_config`, `app_data`)

---

## Configuration Files Priority

Create these files/folders for optimal Claude Code experience:

1. **docs/CLAUDE.md** (Required)
   - Project memory and rules
   - Symlink to root for Claude auto-detection
   - Claude automatically reads this

2. **docs/ARCHITECTURE.md** (Required)
   - System architecture documentation
   - Design decisions and rationale
   - Create at project start

3. **_resources/** (Recommended)
   - Development reference materials
   - NOT in git (add to .gitignore)
   - For draft docs, examples, research

4. **.dockerignore** (If using Docker)
   - Reduces build context
   - Speeds up builds

5. **.gitignore**
   - Must include `_resources/`
   - Exclude generated files
   - Keep repo clean

6. **Custom slash commands**
   - Project-specific shortcuts
   - Repetitive task automation

7. **MCP servers config**
   - Extended capabilities
   - Tool integrations

### Quick Setup
```bash
# Create essential structure
mkdir -p docs _resources/{Examples,Research,Assets,Notes}
touch docs/ARCHITECTURE.md docs/CLAUDE.md
ln -s docs/CLAUDE.md CLAUDE.md
echo "_resources/" >> .gitignore
```

---

## Troubleshooting

### Claude doesn't follow project conventions
→ Add explicit rules to `claude.md` with examples

### Tests keep failing
→ Specify test strategy in `claude.md`
→ Ask: "Use TDD for this feature"

### Code quality issues
→ Document linting/formatting rules in `claude.md`
→ Add pre-commit hooks

### Git history getting messy
→ Configure `git pull --rebase` as default
→ Use `git pr` alias consistently

### Docker builds are slow
→ Review layer caching order
→ Add comprehensive `.dockerignore`
→ Implement multi-stage builds

### Docker permission errors
→ Set `PUID` and `PGID` to match your user: `id -u` and `id -g`
→ Use `UMASK=002` for shared group access
→ Check ownership: `docker exec [container] ls -la /config`
→ Fix permissions: `sudo chown -R [PUID]:[PGID] /path/to/volume`

### Docker logs missing or inaccessible
→ All Binhex containers log to `/config/supervisord.log`
→ View logs: `docker exec [container] cat /config/supervisord.log`
→ Check volume mapping is correct in docker-compose.yml
→ Ensure `/config` directory exists on host

### Docker container won't start
→ Check supervisord.log for startup errors
→ Verify all required environment variables are set
→ Ensure `PUID`/`PGID` have write permissions to volumes
→ Check if ports are already in use: `netstat -tulpn | grep [PORT]`

### Claude seems confused about codebase
→ Have Claude explore and document: "Explain the project structure"
→ Add more context to `claude.md`
→ Use planning mode: `/plan` before implementation

---

## Quick Wins

1. **Set up git alias**: `git config --global alias.pr 'pull --rebase'`
2. **Create docs structure**: `mkdir -p docs _resources/{Examples,Research,Assets,Notes}`
3. **Create ARCHITECTURE.md**: Document system design from day one
4. **Set up _resources/**: Add to .gitignore for dev reference materials
5. **Create claude.md**: In docs/ with symlink to root
6. **Implement Binhex Docker standards**: Use `/config`, `/data`, `/media` + `PUID`/`PGID`
7. **Enable auto-accept**: Speed up workflow once confident
8. **Use planning mode**: For complex features
9. **Add .dockerignore**: Instant build time improvement
10. **Multi-stage Docker**: Dramatically smaller images
11. **Custom commands**: Automate repetitive prompts
12. **Set UMASK=002**: Prevent permission issues with shared files
13. **Check supervisord.log**: First place to look when debugging containers

---

## Resources

- Claude Code Docs: https://docs.claude.com/en/docs/claude-code
- Prompt Engineering: https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering
- MCP Servers: https://github.com/anthropics/mcp-servers

---

**Pro Tip**: The most important thing is your `claude.md` file. Invest time in making it comprehensive, and Claude will work much more effectively with your codebase.
