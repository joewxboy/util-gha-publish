# AGENTS.md

## Project Overview

Docker-based GitHub Action that publishes Open Horizon service definition files to an Open Horizon management hub. The action validates a provided definition file (e.g., `service.definition.json`) from a specified branch, then publishes it using the `hzn` CLI with configuration from `agent-install.cfg` and credentials from GitHub Secrets.

## Project Structure

```
.
├── action.yml              # GitHub Action metadata (inputs, outputs, runs)
├── Dockerfile              # Container image with hzn CLI installed
├── entrypoint.sh           # Main script executed by the action
├── README.md               # Usage documentation for action consumers
├── LICENSE
├── .yamllint.yml           # yamllint configuration (line-length: 120)
├── .github/
│   └── workflows/
│       └── ci.yml          # CI pipeline: lint, build, test
└── test/
    ├── test_entrypoint.sh  # Unit/integration tests for entrypoint
    └── fixtures/           # Sample definition files for testing
        ├── valid_service.definition.json
        └── invalid_service.definition.json
```

## Build & Test Commands

### Build
```bash
docker build -t gha-open-horizon .
```

### Lint
```bash
# Shell scripts (entrypoint.sh, test scripts)
shellcheck entrypoint.sh test/*.sh

# Dockerfile
hadolint Dockerfile

# YAML (action.yml, workflows)
yamllint action.yml .github/workflows/*.yml
```

### Test
```bash
# Run all tests
bash test/test_entrypoint.sh

# Run a single test function (if using bats)
bats test/test_entrypoint.bats --filter "test_name"

# Local action execution via act (requires act installed)
act -j test

# Manual Docker test with mock inputs
docker run --rm \
  -e INPUT_DEFINITION_FILE="service.definition.json" \
  -e INPUT_HZN_ORG_ID="myorg" \
  -e INPUT_HZN_EXCHANGE_USER_AUTH="user:token" \
  -e INPUT_CONFIG_FILE="agent-install.cfg" \
  -v "$(pwd)/test/fixtures:/github/workspace" \
  gha-open-horizon
```

### CI Pipeline
The CI workflow (`.github/workflows/ci.yml`) should run: shellcheck → hadolint → docker build → tests.

## Code Style

### Shell Scripts (entrypoint.sh, tests)

- **Shebang**: Always `#!/bin/bash` (not `#!/bin/sh`) — we need bash features
- **Strict mode**: Every script starts with `set -euo pipefail`
- **Indentation**: 2 spaces, no tabs
- **Naming**: `snake_case` for variables and functions; `UPPER_SNAKE_CASE` for exported/environment variables
- **Quoting**: Always double-quote variable expansions: `"${var}"` not `$var`
- **Functions**: Use `function_name() { ... }` syntax (no `function` keyword)
- **Local variables**: Declare with `local` inside functions
- **ShellCheck compliance**: Zero warnings. Address directives only with justification comment
- **ShellCheck directives**: Must be on their own line with no inline comments. Put justification on a separate comment line above. Example:
  ```bash
  # Justification: variables expand in the bash -c subshell
  # shellcheck disable=SC2016
  ```
  **Wrong**: `# shellcheck disable=SC2016 -- reason` (shellcheck cannot parse inline comments after directives)
- **`bash -c` and SC2016**: Variables inside `bash -c '...'` single-quoted blocks trigger SC2016 even when intentionally meant for subshell expansion. Prefer passing outer-shell variables as positional args (`bash -c '...$1...' _ "${var}"`) but suppress with `# shellcheck disable=SC2016` when subshell variables like `${PATH}` remain
- **Line length**: 100 characters max

```bash
#!/bin/bash
set -euo pipefail

validate_json() {
  local file="${1}"
  if ! jq empty "${file}" 2>/dev/null; then
    echo "::error::Invalid JSON: ${file}"
    return 1
  fi
}
```

### Error Handling

- Use GitHub Actions workflow commands for output: `::error::`, `::warning::`, `::notice::`
- Validate ALL inputs at script start before doing any work
- Provide actionable error messages (what failed, what the user should do)
- Exit with non-zero status on any failure — never silently continue
- Clean up temporary files in a `trap` handler

```bash
cleanup() {
  rm -f "${TEMP_DIR:?}"/*
}
trap cleanup EXIT

# Input validation block at top of entrypoint
: "${INPUT_DEFINITION_FILE:?'definition_file input is required'}"
: "${INPUT_HZN_ORG_ID:?'hzn_org_id input is required'}"
: "${INPUT_HZN_EXCHANGE_USER_AUTH:?'hzn_exchange_user_auth input is required'}"
```

### Dockerfile

- **Base image**: Pin exact digest or version tag, never use `latest`
- **hadolint compliance**: Zero warnings. Use `# hadolint ignore=DLxxxx` for justified suppressions (e.g., DL3008 for utility packages when base image is version-pinned)
- **Labels**: Include `org.opencontainers.image.*` labels
- **User**: Do NOT use `USER` instruction — Docker actions need root for `GITHUB_WORKSPACE` access
- **WORKDIR**: Do NOT set `WORKDIR` — GitHub auto-mounts the workspace
- **ENTRYPOINT**: Use exec form `ENTRYPOINT ["/entrypoint.sh"]` (not shell form)
- **Layer optimization**: Combine related `RUN` commands, clean up package cache
- **COPY vs ADD**: Always use `COPY` unless you specifically need ADD features

```dockerfile
FROM ubuntu:22.04@sha256:<digest>
LABEL org.opencontainers.image.source="https://github.com/OWNER/REPO"

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl jq && \
    rm -rf /var/lib/apt/lists/*

# Install hzn CLI
RUN curl -sSL https://github.com/open-horizon/anax/releases/... | bash

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
```

### action.yml

- **Inputs**: Use `snake_case` names with clear `description` and `required` fields
- **Branding**: Include `icon` and `color` for marketplace visibility
- **Runs**: `using: 'docker'` with `image: 'Dockerfile'`

### YAML

- 2-space indentation
- No trailing whitespace
- Use block scalars (`|`) for multi-line strings
- All YAML files must start with `---` document marker
- Quote the `on` key in GitHub Actions workflows (`"on":`) to avoid yamllint truthy warnings
- Line length configured to 120 chars max via `.yamllint.yml` (default 80 is too restrictive for URLs and descriptions)
- Break long URLs in `run:` blocks with shell line continuation (`\`)

## Open Horizon Specifics

### Key Environment Variables
| Variable | Source | Description |
|----------|--------|-------------|
| `HZN_ORG_ID` | Action input | Organization ID on the exchange |
| `HZN_EXCHANGE_USER_AUTH` | GitHub Secret | Auth string: `iamapikey:<key>` or `user:password` |
| `HZN_EXCHANGE_URL` | agent-install.cfg | Exchange API endpoint |
| `HZN_FSS_CSSURL` | agent-install.cfg | Cloud Sync Service URL |
| `HZN_AGBOT_URL` | agent-install.cfg | AgBot API endpoint |

### Publishing Commands
```bash
# Source config to set HZN_EXCHANGE_URL, HZN_FSS_CSSURL, etc.
source agent-install.cfg

# Publish a service definition
hzn exchange service publish -f service.definition.json

# Publish a pattern
hzn exchange pattern publish -f pattern.json

# Publish a deployment policy
hzn exchange deployment addpolicy -f deployment.policy.json
```

### Definition File Validation
1. **JSON syntax**: `jq empty <file>` — catches malformed JSON
2. **Required fields**: Check for `org`, `url`, `version`, `arch`, `deployment`
3. **Compatibility check**: `hzn deploycheck all -f <file>` (if exchange is reachable)

## GitHub Actions Conventions

- Action inputs are passed as `INPUT_<UPPER_NAME>` environment variables
- Use `$GITHUB_OUTPUT` for setting outputs: `echo "name=value" >> "$GITHUB_OUTPUT"`
- Use `$GITHUB_STEP_SUMMARY` for job summaries
- Secrets must never be logged — redirect sensitive commands: `cmd 2>&1 | sed 's/'"${secret}"'/****/g'`
- The workspace is mounted at `/github/workspace` inside the container

## Security

- Never echo or log `HZN_EXCHANGE_USER_AUTH` — mask it with `::add-mask::`
- Validate definition files BEFORE publishing (prevent injection via malformed JSON)
- Pin all base image versions in the Dockerfile
- Do not store credentials in `agent-install.cfg` — auth comes exclusively from GitHub Secrets
