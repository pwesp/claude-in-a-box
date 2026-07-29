# Claude in a Box

Run [Claude Code](https://claude.ai/code) inside a Docker container, scoped to a single project directory and nothing else on your machine.

The same container works with either backend:

- **Anthropic's hosted models** — Opus, Sonnet, or Haiku, using a Claude subscription (default).
- **A local open-source model** — [Qwen3-Coder](https://ollama.com/library/qwen3-coder) served by [Ollama](https://ollama.com), so nothing leaves the local machine.

Simply run:

```
$ cd /path/to/my-project
$ claude-in-a-box
```

---

## 🤔 Why bother with this container?

So you can take Claude Code off the leash. The launcher runs it with `--dangerously-skip-permissions` — no approval prompts, no babysitting — and that is a reasonable thing to do only because the blast radius is bounded to a single directory by the operating system itself.

Claude Code ships its own sandboxing, so why bother? Because a container boundary does not depend on the agent's cooperation. It holds regardless of a permission rule, whether or not the model behaves as expected, and whether or not something in the workspace tries to talk it into overstepping. Files outside the workspace are not restricted — they are not there.

- **Filesystem isolation.** Claude sees one directory. Your home folder, SSH keys, other projects, and `/etc` are simply not there.
- **Files stay yours.** Docker runs as your own user, so anything Claude creates is owned by you, not root.
- **Per-project state.** Sessions and settings live next to the project rather than in a single global config.
- **A stable Claude Code version.** The auto-updater is disabled, so the version baked into the image is the version you get for that image's whole life — it can't change under you mid-session. Moving forward is a deliberate rebuild.
- **No reach into host services, on the hosted-model backend.** Everything Claude reads is sent to the API, so on that backend the container gets its own network namespace: a database or dev server bound to `localhost` on the host is unreachable. The local-model backend shares the host network instead, because it needs to reach Ollama — and nothing it reads leaves the machine anyway.

It is not a complete jail, though: outbound internet is wide open on both backends, and there are no CPU, memory, or disk limits. See [what this sandbox does and does not protect you from](#-what-this-sandbox-does-and-does-not-protect-you-from) before pointing it at anything sensitive.

## 🔍 How it works

You run a single launch script (`claude-in-a-box`) from any project directory. It starts a Docker container with Claude Code inside, mounts that one directory as the workspace, and points Claude Code at whichever backend your preset (`config.env`) selects. Claude can read and write files in your project directory, nothing else on the local machine is accessible from inside the container.

Your chat history, settings, and preferences are saved alongside your project, so they persist between sessions and stay separate per project.

```
   $ claude-in-a-box
         │
         ▼
┌─ Your machine ──────────────────────────────────────────────┐
│                                                             │
│  ┌─ Docker container ────────────────────────────────────┐  │
│  │                  Claude Code                          │  │
│  └───────────────┬──────────────────┬───────────────────┬┘  │
│                  │                  │                   │   │
│             reads/writes       model requests           │   │
│                  │                  │                   │   │
│                  ▼                  ▼                   │   │
│  ┌────────────────────────┐   ┌──────────────────────┐  │   │
│  │    ~/my-project/       │   │  Ollama on :11434    │  │   │
│  │    (your workspace)    │   │  qwen3-coder + GPU   │  │   │
│  └────────────────────────┘   └──────────────────────┘  │   │
└─────────────────────────────────────────────────────────┬───┘
                                                          ▼
                                    ┌─ Internet ──────────────┐
                                    │    api.anthropic.com    │
                                    │  Opus / Sonnet / Haiku  │
                                    └─────────────────────────┘
```

What's inside the repository:


| Component                     | Role                                                                          |
| ----------------------------- | ----------------------------------------------------------------------------- |
| `Dockerfile`                  | Builds the image: Node 22 slim + Claude Code installed globally               |
| `claude-in-a-box`             | Launch script: mounts your project, wires up the backend, handles permissions |
| `build.sh`                    | Builds/updates the image and deletes the one it replaces                      |
| `config.env`                  | Top-level config: active preset, image name, Ollama URL, token path           |
| `common.sh`                   | Shared config loader sourced by `claude-in-a-box`                             |
| `model_presets/anthropic.env` | Selects Anthropic's hosted models                                             |
| `model_presets/qwen*.env`     | Selects a local Ollama model: model tag + recommended `OLLAMA_*` knobs        |
| `assets/CLAUDE.md`            | Guidance for the local model, baked in at `/etc/claude-code/CLAUDE.md`        |
| `.claude/`                    | Persisted per-project: sessions, history, project config                      |
| `.claude.json`                | Persisted per-project: onboarding state, theme, preferences                   |


---



## ✅ Prerequisites

Always:

- A Linux machine with `sudo` access
- Docker
- An internet connection for the one-time setup

For Anthropic's hosted models: a Claude subscription.

For a local model: [Ollama](https://ollama.com) and a GPU with at least 48 GB VRAM (qwen3-coder:30b uses ~43 GB in practice).

---



## 🛠️ Installation



### Step 1 - Install Docker

Follow the official instructions for your Linux distribution: [https://docs.docker.com/engine/install/](https://docs.docker.com/engine/install/)

### Step 2 - Add your user to the docker group

The launch script runs Docker as your own user. If your user is not in the `docker` group, the script will exit silently without any error message.

To check whether you need this step, run:

```bash
docker ps
```

If that works without `sudo`, skip to Step 3. Otherwise, add yourself to the group:

```bash
sudo usermod -aG docker $USER
```

Apply the group change by exiting your login session and loading into a new one, or with `newgrp`:

```bash
newgrp docker
```

Verify it worked:

```bash
docker run --rm hello-world
```

You should see a "Hello from Docker!" message with no errors.

Note: if you run the launch script with `sudo` instead of fixing group membership, it will appear to work, but the `.claude/` directory and config file will be created as root-owned. Your settings and session history won't persist between runs.

### Step 3 - Clone this repo

```bash
git clone https://github.com/your-username/claude-in-a-box.git
cd claude-in-a-box
```



### Step 4 - Build the Docker image

```bash
./build.sh
```

This takes a minute or two. `build.sh` always builds from scratch (see [Updating](#updating-claude-code-and-the-base-image) for why) and deletes the image it replaced, so repeated builds don't leave orphaned images behind.

The image is based on `[node:22-bookworm-slim](https://hub.docker.com/_/node)`, the official Node.js image maintained by the Node.js Docker team, built on Debian Bookworm. We use it because Claude Code is a Node.js application and this image provides a minimal, well-maintained base. The `-slim` variant strips out things like compilers and documentation to keep the image size down. The tag floats within the Node 22 LTS line, so rebuilds pick up Node patch releases and Debian security updates without ever jumping a major version.

### Step 5 - Set up a backend

Pick one and follow that section, then come back:

- [Anthropic's hosted models](#-backend-anthropics-hosted-models) — needs a subscription token, no GPU
- [A local model via Ollama](#-backend-a-local-model-via-ollama) — needs Ollama and a GPU



### Step 6 - Run it

Make the launch script executable:

```bash
chmod +x claude-in-a-box
```

Navigate to any project directory and launch:

```bash
cd /path/to/my-project
bash /path/to/claude-in-a-box/claude-in-a-box
```

Claude Code starts inside the container. It can only read and write files in `/path/to/my-project` and nothing else on your machine. Your chat history and settings are saved in a `.claude/` folder and a `.claude.json` file that appear alongside your project.

#### Optional for convenience: add it to your PATH

If you want to just type `claude-in-a-box` from any directory instead of the full path:

```bash
echo 'export PATH="$HOME/projects/claude-in-a-box:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Then launching becomes:

```bash
cd /path/to/my-project
claude-in-a-box
```

---



## 🌐 Backend: Anthropic's hosted models

Uses your existing Claude subscription.

### One-time setup

Generate a long-lived token on the host with Claude Code's built-in command, and store it outside this repo:

```bash
mkdir -p ~/.config/claude-in-a-box
claude setup-token                                   # prints the token
printf '%s' 'sk-ant-oat01-...' > ~/.config/claude-in-a-box/claude_code_token
chmod 600 ~/.config/claude-in-a-box/claude_code_token
```

`config.env` holds only the *path* to that file (`CLAUDE_TOKEN_FILE`), never the token itself — `config.env` is committed to git.

This token is separate from the login your host `claude` command uses, so revoking one does not affect the other.

### Selecting this option

In `config.env`:

```sh
PRESET=anthropic
```

Then run `claude-in-a-box` as usual. Choose the model with `/model` inside the session — it is saved to that project's `.claude/settings.json`, so each project remembers its own — or per run with `claude-in-a-box --model sonnet`.

### Network isolation

This backend gets its own network namespace, so **Claude Code cannot reach a database bound to `localhost` on the host** — live database contents can't be read into the model's context. Same for dev servers and internal tools. Everything Claude reads is sent to the API, so restricting what it can reach restricts what can be transmitted.

This does **not** prevent disclosure of anything inside the project directory, which is transmitted to the API as a matter of course. Keep dumps, exports, and `.env` files out of the workspace — that is the larger surface, not the network.

What still works: web search, `WebFetch` on public URLs, remote MCP servers, stdio MCP servers, and any service Claude starts *itself* inside the container (its own `localhost` is the container). What doesn't: a dev server or database **you** are running on the host. Have Claude start it in the container instead — usually preferable anyway, since its experiments then can't collide with your own processes.

---



## 🖥️ Backend: a local model via Ollama

Runs entirely on your own hardware. Nothing leaves the machine.

### One-time setup

Install Ollama:

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

Pull the model (this downloads ~19 GB, so it takes a while):

```bash
ollama pull qwen3-coder:30b
```

Confirm it's available:

```bash
ollama list
```

Ollama must be running whenever you use this backend. The installer sets it up as a system service that starts automatically, but you can also start it manually:

```bash
ollama serve
```

### Selecting this option

In `config.env`, point `PRESET` at one of the local-model presets:

```sh
PRESET=qwen3-coder-30b
```


| Preset                 | Model                     | VRAM   | Context | Notes                                                                                                      |
| ---------------------- | ------------------------- | ------ | ------- | ---------------------------------------------------------------------------------------------------------- |
| `qwen3-coder-30b`      | `qwen3-coder:30b`         | ~20 GB | 32 K    | Fits a 48 GB GPU comfortably.                                                                              |
| `qwen3-coder-next-80b` | `qwen3-coder-next:q4_K_M` | ~52 GB | 64 K    | For an 80 GB H100. Leaves ~28 GB for KV cache (q8_0). Needs a recent Ollama for the hybrid-attention arch. |


To add your own, create `model_presets/<name>.env` with a `MODEL=` line and any `OLLAMA_*` knobs, then set `PRESET=<name>`.

On this backend all three model tiers are pinned to the one local model, so `/model` has no effect — switch models by changing `PRESET` instead.

### Why the image ships extra model guidance

`assets/CLAUDE.md` is baked into the image as an instruction file for Claude Code. It exists because qwen3-coder:30b is a smaller model than the Anthropic-hosted ones and is more prone to mistakes like malformed tool call JSON or unsupported features, so the file nudges it toward more reliable behaviour.

It is baked to the managed-policy path (`/etc/claude-code/CLAUDE.md`) rather than `~/.claude/CLAUDE.md`, because the launcher bind-mounts your project's `.claude` over `/home/node/.claude` and would otherwise shadow it. It does not replace or interfere with any `CLAUDE.md` in your own project: Claude Code reads instructions from multiple locations and merges them, so your project-level `CLAUDE.md` is picked up alongside this one automatically.

That guidance is wrong for a hosted model — it asserts the model is qwen3-coder and tells it to avoid extended thinking and parallel tool calls — so on the Anthropic backend the launcher shadows the file with an empty one.

---



## 🧹 Housekeeping



### Switching backends or models

Change the `PRESET` line in `config.env` to point at a different file in `model_presets/`. No rebuild needed.


| `PRESET`                                  | Backend                     | How you pick the model                    | Host services      |
| ----------------------------------------- | --------------------------- | ----------------------------------------- | ------------------ |
| `anthropic`                               | `api.anthropic.com`         | `/model` in-session, or `--model` per run | unreachable if `localhost`-bound |
| `qwen3-coder-30b`, `qwen3-coder-next-80b` | Ollama on `localhost:11434` | the preset itself                         | reachable (shared network) |




### Updating Claude Code and the base image

The auto-updater is disabled, so a running image never changes under you. The Dockerfile installs from the `stable` channel, so rebuilding — not editing a version — is how you move forward:

```bash
./build.sh
```

It runs `docker build --pull --no-cache`, prints the resulting version, and deletes the image it replaced. Both flags matter: `--no-cache` moves **Claude Code** (the `@stable` line is textually identical every build, so the layer would otherwise be reused), `--pull` moves the **base image** (`--no-cache` doesn't re-resolve the `FROM` tag).

Deletion happens only *after* a successful build, so a failed one leaves you working. But once the old image is gone there's no rollback — `@stable` has moved on. If you depend on the current one, run `docker tag claude-in-a-box claude-in-a-box:previous` first; `build.sh` leaves tagged copies alone. To ride out a bad release, pin `@stable` to an explicit version in the Dockerfile.

To check the channels before rebuilding (npm lives in the image, not on your host):

```bash
docker run --rm --entrypoint npm claude-in-a-box view @anthropic-ai/claude-code dist-tags
```

---



## ⚠️ What this sandbox does and does not protect you from

The Docker container restricts filesystem access to your project directory, but several things can still go wrong. Especially when running with `--dangerously-skip-permissions`, which means Claude acts without asking for confirmation on every action.

**What the container actually prevents**

- Writing files outside the workspace directory
- Reading files outside the workspace directory (your home folder, `/etc`, other users' files)
- Running as root on the host

If you are running this on a shared server, the meaningful risks are: disk exhaustion, GPU monopolisation, and accidental destruction of project files. There is no built-in protection against any of these — they require coordination and good habits.

**Filesystem**

- Claude can read, overwrite, and delete anything inside the mounted workspace. If you point it at a directory containing important files, it can destroy them. Launch from a dedicated project directory, not your home directory.
- **Symlinks pointing out of the workspace are dead inside the container.** Say you launch from `/home/you/project` — that directory alone becomes `/workspace` inside the container. A link `/home/you/project/data` → `/data/sensitive` still shows up in a listing, but `/data` was never mounted, so the target does not exist in the container and cannot be followed. That protects the data, and equally means Claude cannot use it — usually the more surprising half. Relative links that try to climb out (`../../data`) fail the same way. A link to a path that *does* exist in the container, say `/etc`, resolves to the container's own copy rather than your host's.
- **But if the launch directory itself is a symlink, its target is fully mounted.** If `/home/you/project` is itself a link to `/data/project`, the launcher hands `$(pwd)` to Docker, which resolves it host-side — so all of `/data/project` becomes `/workspace`, sensitive files included. Usually what you intended, but run `pwd -P` to see the real path before assuming a symlinked launch directory limits anything.
- Chat history accumulates in `.claude/sessions/`. On a long-running session or a busy shared machine this can grow to several gigabytes. Prune it occasionally with `rm -rf .claude/sessions/`.
- There is no disk quota enforced by Docker on mounted volumes. A runaway task that writes files in a loop will fill up whatever partition your workspace lives on.

**Network**

The network mode depends on the backend, because the risk does.

- **Anthropic backend — own network namespace.** `localhost` inside the container is the container itself, so a host service bound to `127.0.0.1` is structurally unreachable — there is no route to host loopback. A service bound to `0.0.0.0` is a weaker case: it also listens on the Docker gateway and your LAN address, which a bridge container can normally route to, so whether it is reachable comes down to your host firewall rather than to Docker. Verify rather than assume for anything you actually care about.
- **Ollama backend — `--network host`.** It shares your machine's full network stack in order to reach Ollama, so Claude can connect to any service on `localhost` — databases, APIs, internal tools, anything. That is a deliberate trade: a local model transmits nothing off the machine, so reading a local database is not a disclosure. On a shared server, though, those "localhost" services include *other users'*, so don't treat this backend as confined.
- **Outbound internet is open on both.** Neither mode restricts egress — Claude can reach the internet and other machines on your network. The Anthropic backend limits what Claude can *read locally*; it does not limit where data can go.
- **Under `--network host` this cannot be fixed with firewall rules.** The container shares the host's network namespace, so its connection to `127.0.0.1` is indistinguishable from any other local process. If you need a host service to be genuinely unreachable, use the Anthropic backend, or bind that service to an address the container can't route to.

**Compute**

- There are no CPU, memory, or GPU limits set. On the local-model backend, a long agentic task will keep the GPU saturated for as long as it runs, blocking other users on a shared machine.
- Ollama has no per-user request limits. If multiple people run sessions simultaneously, they compete for the same GPU.

**Credentials and secrets**

- If your workspace contains `.env` files, SSH keys, API tokens, or other secrets, Claude can read them. Keep sensitive credentials out of the workspace directory. On the Anthropic backend, anything Claude reads is transmitted to the API — so the workspace, not the network, is the larger disclosure surface.
- Claude does not have access to your home directory or SSH agent by default, but anything inside the mounted workspace is fair game.
- Your subscription token is passed in as an environment variable and is never written into the workspace. It is not on any command line either, so it does not show up in `ps`.

---



## 🔧 Troubleshooting

- `claude-in-a-box` **does nothing / exits immediately**

Make sure you completed Step 2 fully, including the `newgrp docker` step or logging out and back in. Running `docker ps` should work without `sudo`. If it says "permission denied", the group change hasn't taken effect yet.

- `Failed to authenticate. API Error: 401` (Anthropic backend)

The token is being read but rejected. Regenerate it with `claude setup-token` on the host and overwrite the file named by `CLAUDE_TOKEN_FILE`. Make sure the file contains only the token.

- `no readable token at ...` (Anthropic backend)

`CLAUDE_TOKEN_FILE` in `config.env` points at a file that doesn't exist or isn't readable. Check the path and that the file is `chmod 600` and owned by you.

- `connection refused` **reaching the model** (Ollama backend)

Ollama is probably not running. Check with:

```bash
ollama ps
# or
systemctl status ollama
```

Start it if needed:

```bash
ollama serve
```

If you've configured Ollama to listen somewhere other than the default `localhost:11434`, update `OLLAMA_URL` in `config.env`.

- **Theme picker or login screen appears every time**

The launcher seeds a fresh `.claude.json` with onboarding already marked complete, so this should not happen. If it does, `.claude.json` isn't being persisted — check that you're launching from the same directory each time, and that the file isn't root-owned from an earlier `sudo` run.
