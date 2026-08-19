# Developer Setup Guide

> **Purpose**: This guide contains the setup tasks and configurations that human developers should complete before handing off work to Claude Code. Once this setup is complete, Claude can work more autonomously with your codebase.

---

## Table of Contents
1. [Initial Project Setup](#initial-project-setup)
2. [Git Configuration](#git-configuration)
3. [Development Environment](#development-environment)
4. [Claude Code Installation](#claude-code-installation)
5. [Creating Your CLAUDE.md](#creating-your-claudemd)
6. [Testing Setup](#testing-setup)
7. [CI/CD Configuration](#cicd-configuration)
8. [Optional: MCP Servers](#optional-mcp-servers)
9. [Handoff Checklist](#handoff-checklist)

---

## Initial Project Setup

### 1. Clone and Verify Repository
```bash
# Clone the repository
git clone [repository-url]
cd [project-name]

# Verify you're on the correct branch
git branch -a
```

### 2. Create Project Folders
```bash
# Create documentation folder
mkdir -p docs

# Create _resources folder (for development references, NOT in git)
mkdir -p _resources/{Examples,Research,Assets,Notes}

# Verify .gitignore includes _resources
echo "_resources/" >> .gitignore
```

**Folder Purposes**:
- **`docs/`**: All project documentation except README.md
- **`_resources/`**: Development reference materials (never committed)
  - `Examples/` - Code snippets, templates, API samples
  - `Research/` - Research docs, comparisons, notes
  - `Assets/` - Design files, mockups, diagrams
  - `Notes/` - Meeting notes, brainstorming, scratchpad

### 3. Create Initial Documentation

#### Create ARCHITECTURE.md
```bash
# Create architecture documentation file
touch docs/ARCHITECTURE.md
```

**Add to ARCHITECTURE.md** (minimum content):
```markdown
# Architecture

## System Overview
[Brief description of system architecture]

## Component Diagram
[Diagram or description of major components]

## Technology Stack
- Backend: [Technologies]
- Frontend: [Technologies]
- Database: [Database system]
- Infrastructure: [Hosting, containers, etc.]

## Design Decisions
### [Decision 1]
**Context**: [Why this decision was needed]
**Decision**: [What was decided]
**Rationale**: [Why this approach was chosen]
**Consequences**: [Trade-offs and implications]

## Data Flow
[Description of how data flows through the system]

## Security Architecture
[Authentication, authorization, data protection]

## Scalability Considerations
[How the system scales]
```

#### Create/Move CLAUDE.md
```bash
# If CLAUDE.md is in root, move it to docs
mv CLAUDE.md docs/CLAUDE.md

# Create symlink in root so Claude auto-detects it
ln -s docs/CLAUDE.md CLAUDE.md

# Or if creating new
cp path/to/CLAUDE-template.md docs/CLAUDE.md
ln -s docs/CLAUDE.md CLAUDE.md
```

#### Organize Other Documentation
```bash
# Move documentation to docs/ folder (except README.md)
# Keep README.md in root
mv [doc-file].md docs/

# Create standard docs if needed
touch docs/API.md
touch docs/DEPLOYMENT.md
touch docs/DEVELOPMENT.md
```

### 4. Update .gitignore
```bash
# Ensure _resources is ignored
cat >> .gitignore << EOF

# Development resources (not for version control)
_resources/

# OS files
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
*.swp
*.swo
EOF
```

### 5. Install Dependencies
```bash
# Backend dependencies
[package-manager install command]

# Frontend dependencies (if separate)
cd frontend && [package-manager install command]
```

### 6. Environment Configuration
```bash
# Copy environment template
cp .env.example .env

# Edit .env with your local credentials
# Add required API keys, database URLs, etc.
```

**Required Environment Variables**:
- [ ] Database connection strings
- [ ] API keys (development versions)
- [ ] Authentication secrets
- [ ] Third-party service credentials

### 4. Database Setup
```bash
# Create database
[database creation command]

# Run migrations
[migration command]

# Seed with development data
[seed command]
```

---

## Git Configuration

### 1. Set Up Git Aliases for Clean History

Add these aliases to maintain a linear commit history:

```bash
# Preferred: Use git pull --rebase by default
git config --global pull.rebase true

# Or set up custom aliases
git config --global alias.pr 'pull --rebase'
git config --global alias.sync 'pull --rebase origin main'
```

**Why**: This prevents merge commits and keeps history clean. See [Git workflow best practices](./docs/git-workflow.md).

### 2. Configure Git User Info
```bash
git config user.name "Your Name"
git config user.email "your.email@example.com"
```

### 3. Set Up Git Hooks (Optional)
```bash
# Install pre-commit hooks for linting/testing
[pre-commit installation command]
```

### 4. Branch Protection (if you have access)
- [ ] Protect main/production branches
- [ ] Require PR reviews
- [ ] Require CI checks to pass
- [ ] Enable status checks

---

## Development Environment

### 1. IDE/Editor Setup

**Recommended Extensions/Plugins**:
- [ ] Linter extension ([ESLint, RuboCop, etc.])
- [ ] Formatter extension ([Prettier, Black, etc.])
- [ ] Language server/IntelliSense
- [ ] Git integration
- [ ] Docker support (if using containers)

### 2. Local Services

If your project requires local services:

```bash
# Start Docker services
docker-compose up -d

# Or start services individually
[service start commands]
```

**Verify Services Are Running**:
- [ ] Database accessible
- [ ] Redis/cache (if applicable)
- [ ] Message queue (if applicable)
- [ ] Development server starts successfully

### 3. Build and Run
```bash
# Build the project
[build command]

# Start development server
[dev server command]

# In another terminal, start frontend (if separate)
[frontend dev command]
```

**Verify Application Works**:
- [ ] Navigate to `http://localhost:[port]`
- [ ] Can log in (if auth is required)
- [ ] Basic features work
- [ ] API endpoints respond correctly

---

## Claude Code Installation

### 1. Install Claude Code

**Mac/Linux**:
```bash
curl -fsSL https://cli.claude.ai/install.sh | sh
```

**Windows**: Follow instructions at [claude.ai/code](https://docs.claude.com/en/docs/claude-code)

### 2. Verify Installation
```bash
claude --version
```

### 3. Authenticate
```bash
claude auth login
```

### 4. Set Default Model (Optional)
```bash
# Use Sonnet for most tasks (cost-efficient)
claude config set model sonnet

# Or use Opus for complex work
claude config set model opus
```

### 5. Test Claude Code
```bash
# Navigate to your project
cd [project-path]

# Start Claude Code
claude code

# Test with a simple command
# In Claude prompt: "Explain the project structure"
```

---

## Creating Your CLAUDE.md

### 1. Use the Template

The actual CLAUDE.md should live in `/docs` with a symlink in the root:

```bash
# Copy template to docs folder
cp path/to/CLAUDE-template.md docs/CLAUDE.md

# Create symlink in root (for Claude auto-detection)
ln -s docs/CLAUDE.md CLAUDE.md

# Verify symlink works
ls -la CLAUDE.md
# Should show: CLAUDE.md -> docs/CLAUDE.md
```

**Why this structure?**
- All documentation (except README.md) lives in `/docs`
- Symlink in root allows Claude Code to auto-detect the file
- Keeps project root clean
- Makes documentation organization consistent

### 2. Customize Essential Sections

At minimum, fill out these sections:
- [ ] **Project Overview**: What the app does
- [ ] **Technology Stack**: List all major technologies
- [ ] **Project Structure**: Map your directory layout
- [ ] **Development Workflow**: Git strategy, branch naming
- [ ] **Testing Strategy**: Frameworks and preferences
- [ ] **Code Quality Standards**: Linting, formatting tools
- [ ] **Common Tasks**: How to add features, debug, etc.

### 3. Set Claude Code Preferences

Define how you want Claude to work:
- [ ] **Default Model**: Sonnet (fast) or Opus (powerful)
- [ ] **Planning Strategy**: Always plan first? Or dive in?
- [ ] **Testing Approach**: TDD preferred? Tests after? On request?
- [ ] **Auto-Accept Mode**: Enabled or disabled?
- [ ] **Communication Style**: Verbose or concise?

### 4. Document Project-Specific Conventions

Add any rules Claude should always follow:
- Naming conventions
- Code organization patterns
- Security requirements
- Performance considerations
- Error handling approaches

### 5. Let Claude Help

Once you have a basic claude.md, you can ask Claude to improve it:

```bash
# In Claude Code
"Review our claude.md file and suggest improvements based on the codebase"
```

### 6. Use `_resources/` for Development

The `_resources/` folder is your workspace for development materials that shouldn't be in git:

**Store Here**:
- Draft documentation before finalizing
- Research notes and comparisons
- Example code snippets to reference
- API response samples for testing
- Design mockups and wireframes
- Meeting notes and brainstorming
- Claude prompts and AI interaction logs

**Example Usage**:
```bash
# Store example API responses for reference
curl https://api.example.com/users/1 > _resources/Examples/UserApiResponse.json

# Save research notes
echo "Comparison of Redis vs Memcached" > _resources/Research/CachingOptions.md

# Store design assets
cp ~/Downloads/mockup.png _resources/Assets/

# Keep development notes
echo "TODO: Refactor auth module" > _resources/Notes/DevTasks.md
```

**Ask Claude to Use It**:
```
"Store this example in _resources/Examples for future reference"
"Check _resources/Research for notes on our caching decision"
"Reference the API examples in _resources/Examples/"
```

**Important**: 
- This folder is NEVER committed to git
- Perfect for temporary or reference materials
- Claude can read from and write to this folder
- Developers can freely add/modify content

---

## Testing Setup

### 1. Verify Test Framework Works
```bash
# Run all tests
[test command]

# Should see results - even if some fail, framework should work
```

### 2. Configure Test Coverage
```bash
# Install coverage tool if not present
[coverage installation command]

# Run tests with coverage
[coverage command]

# Verify coverage reports are generated
```

### 3. Set Up E2E Testing (if applicable)
```bash
# Install E2E framework
[e2e installation command]

# Verify E2E tests can run
[e2e test command]
```

### 4. Document Testing Preferences

In your `claude.md`, specify:
- [ ] When to write tests (TDD? After? On request?)
- [ ] Required test coverage percentage
- [ ] Which test frameworks to use
- [ ] How to structure test files

---

## CI/CD Configuration

### 1. Set Up GitHub Actions (or equivalent)

Create `.github/workflows/main.yml`:

```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run tests
        run: [your test command]
      - name: Run linter
        run: [your lint command]
```

### 2. Enable GitHub Integration (Optional)

For Claude Code to automatically fix issues and create PRs:

1. Install the Claude Code GitHub App
2. Grant repository access
3. Tag issues with `@claude` to trigger Claude

### 3. Verify CI Pipeline
- [ ] Push a test commit
- [ ] Verify CI runs
- [ ] Check that tests execute
- [ ] Confirm status checks work

---

## Docker Optimization (if using Docker)

### 1. Implement Binhex Standardization

All Docker containers should follow the Binhex standard for consistency:

#### Standard Volume Structure
```yaml
volumes:
  - /mnt/user/appdata/[AppName]:/config
  - /mnt/user/data:/data
  - /mnt/user/media:/media
```

**Volume Purposes:**
- `/config` - All configuration files, databases, and logs (including supervisord.log)
- `/data` - Application data, downloads, working files
- `/media` - Media files (movies, TV shows, music, pictures)

#### Standard Environment Variables
```yaml
environment:
  # User/Group Management
  - PUID=1000                    # Your user ID (find with: id -u)
  - PGID=1000                    # Your group ID (find with: id -g)
  - UMASK=002                    # File permissions (002 recommended)
  
  # System Configuration
  - TZ=America/New_York          # Your timezone
  - DEBUG=false                  # Enable debug logging
  
  # Application-specific variables
  - [YOUR_APP_VARIABLES]
```

#### Setting Up PUID/PGID
```bash
# Find your user and group IDs
id -u        # Returns your PUID (e.g., 1000)
id -g        # Returns your PGID (e.g., 1000)

# Or for a specific user
id -u username
id -g username
```

**UMASK Values:**
- `000` - Full permissions (777 folders, 666 files) - most permissive
- `002` - Group writable (775 folders, 664 files) - **recommended**
- `022` - User writable only (755 folders, 644 files) - more restrictive

### 2. Review Dockerfile

Ensure your Dockerfile follows best practices:

```dockerfile
# ✅ Use minimal base image
FROM alpine:3.19 AS BuildStage

# ✅ Dependencies before code (for layer caching)
COPY package*.json ./
RUN npm install

# ✅ Then copy application code
COPY . .

# ✅ Multi-stage build
FROM alpine:3.19
WORKDIR /app

# Standard Binhex volume paths
VOLUME ["/config", "/data", "/media"]

# Copy only necessary files from build stage
COPY --from=BuildStage /app/dist ./dist

# Standard Binhex environment variables with defaults
ENV PUID=99 \
    PGID=100 \
    UMASK=000 \
    TZ=UTC

CMD ["./start.sh"]
```

### 3. Create/Update .dockerignore

```
node_modules
.git
.env
*.log
coverage
.DS_Store
.vscode
.idea
dist
build
```

### 4. Create Docker Compose File

Create `docker-compose.yml` following Binhex standards:

```yaml
version: '3.8'

services:
  [AppName]:
    image: [your-image-name]
    container_name: [ContainerName]
    restart: unless-stopped
    
    # Standard Binhex volume mappings
    volumes:
      - ./config:/config          # Config and logs
      - ./data:/data              # Data and downloads
      - ./media:/media            # Media files
    
    # Standard Binhex environment variables
    environment:
      - PUID=1000
      - PGID=1000
      - UMASK=002
      - TZ=America/New_York
      - DEBUG=false
      # Add application-specific variables below
      - [APP_VARIABLE]=${APP_VARIABLE}
    
    ports:
      - "8080:8080"
    
    # Optional: network configuration
    networks:
      - [NetworkName]

networks:
  [NetworkName]:
    driver: bridge
```

### 5. Test Docker Build
```bash
# Build image
docker build -t [ImageName] .

# Check image size
docker images [ImageName]

# Run container with Binhex standards
docker run -d \
  --name [ContainerName] \
  -v $(pwd)/config:/config \
  -v $(pwd)/data:/data \
  -v $(pwd)/media:/media \
  -e PUID=$(id -u) \
  -e PGID=$(id -g) \
  -e UMASK=002 \
  -e TZ=America/New_York \
  -p 8080:8080 \
  [ImageName]

# Or use docker-compose
docker-compose up -d

# Check logs
docker logs [ContainerName]

# Check detailed logs (Binhex standard)
docker exec [ContainerName] cat /config/supervisord.log
```

### 6. Verify Volume Mappings
```bash
# Check if volumes are properly mounted
docker inspect [ContainerName] | grep -A 10 Mounts

# Check file permissions inside container
docker exec [ContainerName] ls -la /config
docker exec [ContainerName] ls -la /data
docker exec [ContainerName] ls -la /media

# Verify PUID/PGID are set correctly
docker exec [ContainerName] id
```

### 7. Configure Supervisord (if using)

If your container uses supervisord (Binhex standard), create `/etc/supervisord.conf`:

```ini
[supervisord]
nodaemon=true
user=root
logfile=/config/supervisord.log
logfile_maxbytes=50MB
logfile_backups=3
loglevel=info
pidfile=/var/run/supervisord.pid

[program:YourApp]
command=/app/start.sh
autostart=true
autorestart=true
startsecs=5
stdout_logfile=/config/supervisord.log
stderr_logfile=/config/supervisord.log
```

**Optimization Goals**:
- [ ] Minimal base image (Alpine or Distroless)
- [ ] Multi-stage build for smaller final image
- [ ] Layer caching optimized
- [ ] `.dockerignore` excludes unnecessary files
- [ ] Combined RUN commands to reduce layers
- [ ] Binhex standard paths implemented (/config, /data, /media)
- [ ] Binhex standard environment variables configured (PUID, PGID, UMASK, TZ)
- [ ] Supervisord logging to /config/supervisord.log

---

## Optional: MCP Servers

MCP (Model Context Protocol) servers extend Claude's capabilities.

### Database MCP (for direct DB access)

**PostgreSQL**:
```bash
# Install
npm install -g @anthropic-ai/mcp-server-postgres

# Configure in Claude settings
claude config set mcp.postgres.url "postgresql://..."
```

**MongoDB**:
```bash
# Install
npm install -g @anthropic-ai/mcp-server-mongodb

# Configure
claude config set mcp.mongodb.url "mongodb://..."
```

### Playwright MCP (for browser automation)
```bash
# Install
npm install -g @anthropic-ai/mcp-server-playwright

# Enable in Claude Code
claude config set mcp.playwright.enabled true
```

### Figma MCP (for design-to-code)
```bash
# Install
npm install -g @anthropic-ai/mcp-server-figma

# Add Figma API key
claude config set mcp.figma.token "your-figma-token"
```

---

## Handoff Checklist

Before handing off work to Claude, ensure:

### ✅ Environment Setup
- [ ] Project runs successfully locally
- [ ] All dependencies installed
- [ ] Database configured and seeded
- [ ] Environment variables set
- [ ] Tests can run and pass

### ✅ Git Configuration
- [ ] Git aliases configured (`git pr` for pull --rebase)
- [ ] Branch strategy documented
- [ ] Pre-commit hooks working (if used)

### ✅ Claude Code Ready
- [ ] Claude Code installed and authenticated
- [ ] `claude.md` file created and customized
- [ ] Claude Code preferences set
- [ ] Tested with simple prompt

### ✅ Documentation
- [ ] `docs/` folder created
- [ ] `_resources/` folder created (added to .gitignore)
- [ ] `ARCHITECTURE.md` created in docs/ with system overview
- [ ] `claude.md` in docs/ with symlink in root
- [ ] Code quality tools configured
- [ ] Testing strategy defined
- [ ] Common tasks documented
- [ ] README.md updated with project overview

### ✅ Optional Enhancements
- [ ] CI/CD pipeline configured
- [ ] Docker optimized (if applicable)
- [ ] MCP servers installed (if needed)
- [ ] Custom slash commands created
- [ ] GitHub integration enabled

---

## Testing Claude Code

### 1. Simple Test

Start Claude Code and try:
```
"Create a to-do list of tasks needed to add a new user profile feature"
```

Claude should generate a structured task list.

### 2. Code Generation Test
```
"Write a simple unit test for [specific function/component]"
```

Verify Claude:
- Understands your test framework
- Follows your project conventions
- Generates runnable tests

### 3. Codebase Understanding Test
```
"Explain how authentication works in this application"
```

Claude should demonstrate understanding of your architecture.

### 4. If Issues Occur

**Claude seems confused about the project**:
- Add more detail to your claude.md
- Provide explicit examples of conventions
- Use planning mode: `think hard about the architecture`

**Claude makes syntax errors**:
- Verify language and framework versions in claude.md
- Add linting rules to claude.md
- Ask Claude to read your linter config

**Claude violates conventions**:
- Explicitly document the convention in claude.md
- Provide before/after examples
- Set it as a hard rule in "Coding Conventions" section

---

## Next Steps

Once setup is complete:

1. **Start Small**: Give Claude simple, well-defined tasks
2. **Iterate on claude.md**: Update it as you discover what Claude needs to know
3. **Use Planning Mode**: For complex tasks, ask Claude to plan first
4. **Leverage Subagents**: For exploration or parallel work
5. **Enable Auto-Accept**: Once confident, to speed up workflows

### Resources

- [Claude Code Documentation](https://docs.claude.com/en/docs/claude-code)
- [Prompt Engineering Guide](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview)
- [MCP Servers](https://github.com/anthropics/mcp-servers)
- Your `claude.md` file

---

## Common Issues and Solutions

### "Module not found" errors
- Ensure dependencies are installed
- Check node/python version matches requirements
- Verify virtual environment is activated (if applicable)

### Tests fail on first run
- Check database is seeded
- Verify test environment variables are set
- Ensure test database is separate from development

### Claude Code authentication fails
- Run `claude auth logout` then `claude auth login`
- Check internet connection
- Verify Claude.ai account is active

### Git conflicts during pull --rebase
- Use `git rebase --abort` to undo
- Then use `git pull` (without --rebase) to merge
- Resolve conflicts in the merge commit
- Future pulls: continue using `git pull --rebase`

### Docker permission issues
- Set correct `PUID`/`PGID` environment variables matching your host user
- Find your IDs: `id -u` (PUID) and `id -g` (PGID)
- Use `UMASK=002` for shared group access
- Check container file ownership: `docker exec [container] ls -la /config`
- Fix host permissions if needed: `sudo chown -R [PUID]:[PGID] /path/to/volume`

### Cannot find Docker logs or config files
- All Binhex containers log to `/config/supervisord.log`
- View logs: `docker exec [container] cat /config/supervisord.log`
- Check volume mapping: `docker inspect [container] | grep -A 10 Mounts`
- Verify host path exists: `ls -la /path/to/host/volume`

### Docker container keeps restarting
- Check supervisord log: `docker exec [container] cat /config/supervisord.log`
- View container logs: `docker logs [container]`
- Verify volumes are properly mounted
- Ensure `PUID`/`PGID` have write access to `/config`
- Check if required environment variables are set

### Docker builds failing
- Review layer caching order (dependencies before code)
- Ensure `.dockerignore` is configured
- Check base image is accessible
- Verify multi-stage build syntax
- Clear build cache: `docker builder prune`

---

## Maintenance

### Weekly Tasks
- [ ] Update dependencies: `[update command]`
- [ ] Review and update claude.md if needed
- [ ] Check CI/CD pipeline is working
- [ ] Review Claude Code's recent work

### Monthly Tasks
- [ ] Review test coverage
- [ ] Update documentation
- [ ] Check for security updates
- [ ] Audit and clean up technical debt

---

**Questions or Issues?**

- Check the [Claude Code documentation](https://docs.claude.com)
- Ask Claude: "Help me troubleshoot my development environment"
- Contact: [your-team-contact]
