# claudebox

Claude in a box

<img width="2781" height="1331" alt="Gemini_Generated_Image_3bck2g3bck2g3bck" src="https://github.com/user-attachments/assets/86776f7e-f717-4d5d-92b9-87bfc57a3dad" />

## Why?

- **Use it however you want**: Run Claude from your terminal as a CLI, or drop it into an existing Docker Compose stack as a service.
- **No API key, no extra billing**: claudebox uses your existing Claude subscription and authenticates with your current Claude credentials, so personal use feels seamless.
- **Real agent, strong isolation**: Claude gets its full toolset inside the container—file editing, shell access, code analysis, and more; without access to your host machine or the open internet beyond Anthropic’s APIs.

## Prerequisites

- **Docker** — [Install Docker Desktop](https://docs.docker.com/get-docker/)
- **Claude CLI** — installed and authenticated (`curl -fsSL https://claude.ai/install.sh | bash`, then run `claude` once to log in)

claudebox uses your Claude subscription. It reads local credentials (Keychain on macOS, `~/.claude/.credentials.json` on Linux) to authenticate inside the container. Credentials are resolved in order: `CLAUDE_CODE_OAUTH_TOKEN` env var, then platform credential store.

## Use as a CLI tool

**For:** running prompts and agentic tasks in a sandboxed container from your terminal.

### Install

```bash
curl -fsSL https://raw.githubusercontent.com/ArmanJR/claudebox/main/install.sh | bash
```

### Usage

```bash
claudebox prompt "explain how DNS works"    # run a single prompt
claudebox prompt --json "explain DNS"       # full JSON output
claudebox prompt --verbose "explain DNS"    # container logs + output
claudebox server                            # start the HTTP API server
claudebox stop                              # stop the server
claudebox logs                              # view server logs
claudebox status                            # check if server is running
claudebox version                           # show CLI version
claudebox update                            # update the CLI
```

Works on macOS and Linux. Handles authentication automatically and refreshes expired tokens before launching the container.

### Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `CLAUDEBOX_PORT` | `3000` | Host port |
| `CLAUDEBOX_IMAGE` | `ghcr.io/armanjr/claudebox:latest` | Docker image |
| `CLAUDEBOX_NAME` | `claudebox` | Container name |
| `CLAUDE_CODE_OAUTH_TOKEN` | — | Skip auto-detection, use this token directly |

## Use as a service

**For:** adding Claude as an agent alongside other services in your Docker Compose stack.

### Add to your docker-compose.yml

First, extract your OAuth token (re-run when it expires):

```bash
curl -fsSL https://raw.githubusercontent.com/ArmanJR/claudebox/main/setup-auth.sh | bash
```

```yaml
services:
  claudebox:
    image: ghcr.io/armanjr/claudebox:latest
    cap_add:
      - NET_ADMIN
    ports:
      - "3000:3000"
    env_file:
      - path: .env.claude
        required: true
```

Then `docker compose up -d`. Other services in the same network reach Claude at `http://claudebox:3000`.

### HTTP API

#### `POST /prompt`

Send a prompt to Claude and get a JSON response.

```json
{
  "prompt": "your prompt here",
  "options": {
    "model": "sonnet",
    "maxTurns": 10,
    "maxBudgetUsd": 1.0,
    "systemPrompt": "you are a helpful assistant",
    "appendSystemPrompt": "additional instructions",
    "allowedTools": ["Read", "Edit", "Bash"],
    "cwd": "/workspace"
  }
}
```

All fields in `options` are optional.

**Response:** Claude Code's JSON output (includes `result`, `session_id`, `usage`, `total_cost_usd`, etc.)

#### `GET /health`

Returns `{"status": "ok", "activeRequests": 0}`.

#### Server environment variables

| Variable | Default | Purpose |
|---|---|---|
| `PORT` | `3000` | Server listen port |
| `MAX_CONCURRENT` | `4` | Max parallel Claude processes |

## How It Works

**Network isolation** — iptables firewall blocks all outbound traffic except Anthropic API domains (baked into the image). To allow additional domains, mount a custom allowlist:

```bash
-v /path/to/allowed-domains.txt:/etc/allowed-domains.txt:ro
```

**Workspace** — `/workspace` is writable so Claude can create and edit files. Mount context files read-only at `/workspace/context` for reference (put your `CLAUDE.md` there).

## Limitations

**IP-based firewall** — Domain allowlisting resolves IPs at container start. If Anthropic's CDN/load-balancer IPs rotate during the container's lifetime, connections will fail. Restart the container to re-resolve. This is an inherent limitation of iptables-based filtering.

## Building Locally

```bash
docker compose up -d --build
```

To pin a specific Claude Code version:

```bash
docker compose build --build-arg CLAUDE_CODE_VERSION=2.1.80
```

## License

MIT
