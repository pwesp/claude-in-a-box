# Claude in a Box

Run [Claude Code](https://claude.ai/code) locally, backed by a free open-source model ([Qwen3-Coder](https://ollama.com/library/qwen3-coder) via [Ollama](https://ollama.com)), inside a Docker container.

Claude Code gets access only to the directory you launch it from nothing else on your machine.

Simply run:

```
$ cd /path/to/my-project
$ qwen-claude
```

---

## 🔍 How it works

You run a single launch script (`qwen-claude`) from any project directory on your machine. It starts a Docker container with Claude Code inside, pointed at a locally running Ollama instance serving the Qwen3-Coder model. Claude can read and write files in your project directory, and that's it. Nothing else on your machine is accessible from inside the container.

Your chat history, settings, and preferences are saved alongside your project so they persist between sessions.

```
   $ qwen-claude
         │
         ▼
┌─ Your machine ──────────────────────────────────────────┐
│                                                         │
│  ┌─ Docker container ───────────────────────────────┐   │
│  │                                                  │   │
│  │                  Claude Code                     │   │
│  │                                                  │   │
│  └───────────────┬──────────────────────────────────┘   │
│                  │                       ▲              │
│                  │                       │              │
│             reads/writes          API (localhost:11434) │
│                  │                       │              │
│                  ▼                       │              │
│  ┌────────────────────────┐   ┌──────────┴───────────┐  │
│  │    ~/my-project/       │   │        Ollama        │  │
│  │    (your workspace)    │   │   qwen3-coder:30b    │  │
│  └────────────────────────┘   └──────────────────────┘  │
│                                          │              │
│                                         GPU             │
└─────────────────────────────────────────────────────────┘
```


| Component          | Role                                                                          |
| ------------------ | ----------------------------------------------------------------------------- |
| `Dockerfile`       | Builds the image: Node 22 slim + Claude Code installed globally               |
| `assets/CLAUDE.md` | Model guidance baked into the image at `/home/node/.claude/CLAUDE.md`         |
| `qwen-claude`      | Launch script: mounts your project, wires up Ollama, handles user permissions |
| `.claude/`         | Persisted per-project: sessions, history, project config                      |
| `.claude.json`     | Persisted globally: theme, preferences                                        |


The script runs Docker as your own user so that files Claude creates in your project are owned by you, not by root.

`assets/CLAUDE.md` is baked into the image as a global instruction file for Claude Code. It exists because qwen3-coder:30b is a smaller model than the Anthropic-hosted ones and is more prone to mistakes like malformed tool call JSON or unsupported features. The file nudges it toward more reliable behaviour. It does not replace or interfere with any `CLAUDE.md` in your own project: Claude Code reads instructions from multiple locations and merges them, so your project-level `CLAUDE.md` is picked up alongside this one automatically.

---

## ✅ Prerequisites

- A Linux machine with `sudo` access
- A GPU with at least 48 GB VRAM (qwen3-coder:30b uses ~43 GB in practice)
- An internet connection for the one-time setup

---

## 🛠️ Installation

### Step 1 - Install Docker

Follow the official instructions for your Linux distribution: [https://docs.docker.com/engine/install/](https://docs.docker.com/engine/install/)

### Step 2 - Add your user to the docker group

The launch script `qwen-claude` runs Docker as your own user. If your user is not in the `docker` group, the script will exit silently without any error message.

To check whether you need this step, run:

```bash
docker ps
```

If that works without `sudo`, skip to Step 3. Otherwise, add yourself to the group:

```bash
sudo usermod -aG docker $USER
```

Apply the group change by exiting your login session and loading into new one or with `newgrp`:

```bash
newgrp docker
```

Verify it worked:

```bash
docker run --rm hello-world
```

You should see a "Hello from Docker!" message with no errors.

Note: if you run the launch script with `sudo` instead of fixing group membership, it will appear to work, but the `.claude/` directory and config file will be created as root-owned. Your settings and session history won't persist between runs.

### Step 3 - Install Ollama and pull the model

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

You should see `qwen3-coder:30b` (or whichever variant you pulled) in the list.

Ollama must be running whenever you use `qwen-claude`. The installer sets it up as a system service that starts automatically, but you can also start it manually if needed:

```bash
ollama serve
```

### Step 4 - Clone this repo

```bash
git clone https://github.com/your-username/claude-in-a-box.git
cd claude-in-a-box
```

### Step 5 - Build the Docker image

```bash
docker build -t claude-qwen .
```

This takes a minute or two the first time. Subsequent builds are fast because Docker caches the layers.

The image is based on `[node:22-bookworm-slim](https://hub.docker.com/layers/library/node/22.22.2-bookworm-slim)`, the official Node.js image maintained by the Node.js Docker team, built on Debian Bookworm. We use it because Claude Code is a Node.js application and this image provides a minimal, well-maintained base. The `-slim` variant strips out things like compilers and documentation to keep the image size down.

### Step 6 - Run it

Make the launch script executable:

```bash
chmod +x qwen-claude
```

Navigate to any project directory and launch:

```bash
cd /path/to/my-project
bash /path/to/claude-in-a-box/qwen-claude
```

Claude Code starts inside the container. It can only read and write files in `/path/to/my-project` and nothing else on your machine. Your chat history and settings are saved in a `.claude/` folder and a `.claude.json` file that appear alongside your project.

#### Optional for convenience: Add qwen-claude to your PATH environment

If you want to just type `qwen-claude` from any directory instead of the full path:

```bash
echo 'export PATH="$HOME/projects/claude-in-a-box:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Then launching becomes:

```bash
cd /path/to/my-project
qwen-claude
```

---

## 🧹 Housekeeping

### Switching models

If you want to use a different Ollama model, edit the three `ANTHROPIC_DEFAULT_*_MODEL` lines in the `qwen-claude` launch script to match the exact tag shown by `ollama list`. No image rebuild needed.

### Updating Claude Code

The auto-updater is disabled inside the container. This is intentional, allowing Claude Code to update itself at runtime would silently change what's running inside the image, making your setup harder to reproduce and reason about. To update, find the latest version on the [Claude Code npm page](https://www.npmjs.com/package/@anthropic-ai/claude-code), update the version in the Dockerfile (`npm install -g @anthropic-ai/claude-code@x.y.z`), and rebuild the image.

```bash
cd ~/projects/claude-in-a-box
docker build --no-cache -t claude-qwen .
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
- Chat history accumulates in `.claude/sessions/`. On a long-running session or a busy shared machine this can grow to several gigabytes. Prune it occasionally with `rm -rf .claude/sessions/`.
- There is no disk quota enforced by Docker on mounted volumes. A runaway task that writes files in a loop will fill up whatever partition your workspace lives on.

**Network**

- The container runs with `--network host`, meaning it shares your machine's full network stack. Claude can make outbound requests to the internet, reach other machines on your local network, and connect to any service running on `localhost` — databases, APIs, internal tools, anything. It is not network-isolated.
- On a shared server, "localhost" services are visible to all users' containers, not just yours.

**Compute**

- There are no CPU, memory, or GPU limits set. A long agentic task will keep the GPU saturated for as long as it runs, blocking other users on a shared machine.
- Ollama has no per-user request limits. If multiple people run sessions simultaneously, they compete for the same GPU.

**Credentials and secrets**

- If your workspace contains `.env` files, SSH keys, API tokens, or other secrets, Claude can read them. Keep sensitive credentials out of the workspace directory.
- Claude does not have access to your home directory or SSH agent by default, but anything inside the mounted workspace is fair game.

---

## 🔧 Troubleshooting

`**qwen-claude` does nothing / exits immediately**

Make sure you completed Step 2 fully, including the `newgrp docker` step or logging out and back in. Running `docker ps` should work without `sudo` — if it says "permission denied", the group change hasn't taken effect yet.

`**ollama: connection refused` or similar inside Claude Code**

The launch script assumes Ollama is listening on its default address (`localhost:11434`). If you've configured Ollama to use a different address, update the `ANTHROPIC_BASE_URL` line in the `qwen-claude` script accordingly.

Otherwise, Ollama may simply not be running. Check with:

```bash
ollama ps
# or
systemctl status ollama
```

Start it if needed:

```bash
ollama serve
```

**Theme picker or login screen appears every time**

This means the `.claude.json` config file isn't being persisted. It should appear in your project directory after the first run. Check that you're launching from the same directory each time.