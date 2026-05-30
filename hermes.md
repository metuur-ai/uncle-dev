[Skip to content](https://blakecrosley.com/guides/hermes#main)

[Blake Crosley](https://blakecrosley.com/)

[About](https://blakecrosley.com/about) · [Work](https://blakecrosley.com/#work) · [Writing](https://blakecrosley.com/writing) · [Guides](https://blakecrosley.com/guides) · [Contact](https://blakecrosley.com/#contact)

# Hermes Agent v0.10 Reference: SOUL.md + Smart Model Routing

SOUL.md, smart model routing, heartbeat.md, providers, env vars, and inference errors. Use official docs for setup; use Blake's reference.

- Words: 13,262
- Read time: 66m
- Updated: 2026-04-16 00:00

```text
$ ls -la ./sections/
drwxr-xr-x 26 sections

$ less hermes.md
```

> **TL;DR:** Hermes Agent is an open-source self-improving AI agent from Nous Research. It runs as a CLI and as a multi-platform messaging gateway, stores a durable identity and persistent memory on disk, aggregates skills that improve with use, and works with any OpenAI-compatible LLM provider — Nous Portal, OpenRouter, Anthropic, GitHub Copilot, z.ai, Kimi, MiniMax, DeepSeek, Alibaba, Hugging Face, Google, or your own self-hosted endpoint.[1](https://blakecrosley.com/guides/hermes#fn:1)[2](https://blakecrosley.com/guides/hermes#fn:2) The hardest part for most new users is provider authentication: Hermes supports ~19 first-class providers plus custom endpoints, and three distinct auth paths (API key in `.env`, OAuth via `hermes model`, or custom endpoint in `config.yaml`). The auth model is the thing to learn first — everything else is downstream of which provider is resolved.

**Hermes Agent operates as a full agent runtime**, not a chat wrapper. It reads your filesystem, executes commands in sandboxed backends, scrapes the web, spawns subagents, runs scheduled cron jobs, talks to Telegram/Discord/Slack/WhatsApp/Signal/Email from a single gateway process, and creates its own skills from experience.[1](https://blakecrosley.com/guides/hermes#fn:1) The CLI is a terminal UI built on top of a conversation loop in `run_agent.py`; the gateway is a long-running process that routes messages from messaging platforms through the same conversation loop.[3](https://blakecrosley.com/guides/hermes#fn:3)

> **The difference between casual and expert Hermes usage comes down to five systems.** Master these and Hermes becomes a force multiplier:

1. **Provider resolution**: how auth flows map to API calls
2. **Configuration hierarchy**: `config.yaml` + `.env` + `auth.json` + `SOUL.md` + `AGENTS.md`
3. **Tool + toolset system**: what the agent can do, gated per platform
4. **Skills system**: procedural memory the agent creates and evolves
5. **Gateway + cron + profiles**: running Hermes where you live, not just where you are

### Key Takeaways

- **Provider auth is three paths, not one.** API key in `.env`, OAuth via `hermes model`/`hermes auth`, or custom endpoint in `config.yaml`. Pick the path that matches your provider, not the one that feels familiar.
- **Switching providers is a single command.** `hermes model` interactively walks you through every supported provider including OAuth logins, and `/model provider:model` switches mid-session without losing history.[2](https://blakecrosley.com/guides/hermes#fn:2)
- **Two files are the user-editable config surface.** `~/.hermes/config.yaml` holds settings and `~/.hermes/.env` holds secrets. `auth.json`, `SOUL.md`, `MEMORY.md`, and `skills/` are managed by Hermes directly — you can edit `SOUL.md` by hand, but the rest is touched by the agent itself.[4](https://blakecrosley.com/guides/hermes#fn:4)
- **Hermes is the successor to OpenClaw.** If you’re migrating, `hermes claw migrate` imports 30+ categories of state automatically.[5](https://blakecrosley.com/guides/hermes#fn:5)
- **Quality of service depends on your auxiliary model.** Vision, web summarization, compression, and memory flush all use a separate auxiliary LLM. By default this is Gemini Flash via auto-detection (OpenRouter → Nous → Codex) — if none of those are configured, these features degrade silently until you point the auxiliary slots at your main provider.[4](https://blakecrosley.com/guides/hermes#fn:4)

Every section below is grounded in the upstream documentation at [hermes-agent.nousresearch.com/docs](https://hermes-agent.nousresearch.com/docs/) and the source tree at [github.com/NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent). Every factual claim has a footnote pointing at the specific upstream page it came from.

### Choose Your Path

| What you need                            | Go here                                                                                                                                                                                                                   |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Install Hermes**                       | [Installation](https://blakecrosley.com/guides/hermes#installation) — one-line installer or manual steps                                                                                                                  |
| **Sign into a provider**                 | [Authentication & Providers](https://blakecrosley.com/guides/hermes#authentication-providers) — the section you came here for                                                                                             |
| **Switch models mid-session**            | [The `hermes auth` Command](https://blakecrosley.com/guides/hermes#the-hermes-auth-command) and [Custom & Self-Hosted Endpoints](https://blakecrosley.com/guides/hermes#custom-self-hosted-endpoints) for `/model` syntax |
| **Run a local LLM**                      | [Custom & Self-Hosted Endpoints](https://blakecrosley.com/guides/hermes#custom-self-hosted-endpoints) — Ollama, vLLM, SGLang, llama.cpp, LM Studio                                                                        |
| **Connect messaging platforms**          | [Messaging Gateway](https://blakecrosley.com/guides/hermes#messaging-gateway) — Telegram, Discord, Slack, WhatsApp, Signal                                                                                                |
| **Write or install a skill**             | [Skills System](https://blakecrosley.com/guides/hermes#skills-system) — progressive disclosure + skill hub                                                                                                                |
| **Deep reference for every CLI command** | Keep reading — and link directly to [CLI Commands](https://blakecrosley.com/guides/hermes#cli-commands)                                                                                                                   |

---

## How Hermes Works: The Mental Model

Hermes is structured around a single conversation loop that any entry point can invoke. The entry points are the CLI (`cli.py`), the messaging gateway (`gateway/run.py`), the ACP adapter for editor integration, the batch runner, and an API server.[3](https://blakecrosley.com/guides/hermes#fn:3) All of them ultimately call `AIAgent.run_conversation()` in `run_agent.py`, which:

1. Builds the system prompt from `SOUL.md`, `MEMORY.md`, `USER.md`, skills, context files, and tool guidance via `prompt_builder.py`[3](https://blakecrosley.com/guides/hermes#fn:3)
2. Resolves the runtime provider via `runtime_provider.py` — this is the step that picks your auth, base URL, and API mode[3](https://blakecrosley.com/guides/hermes#fn:3)
3. Calls the provider using one of three API modes: `chat_completions`, `codex_responses`, or `anthropic_messages`[3](https://blakecrosley.com/guides/hermes#fn:3)
4. Dispatches any returned tool calls through `model_tools.py` and the central tool registry (`tools/registry.py`)[3](https://blakecrosley.com/guides/hermes#fn:3)
5. Loops until the model produces a final response, then persists the session to SQLite with FTS5[3](https://blakecrosley.com/guides/hermes#fn:3)

Understanding this loop matters because every feature — personalities, memory, skills, compression, fallback — attaches to one of these stages. When you’re reading a config key and wondering what it does, the answer is usually “it’s a knob on stage 1, 2, 3, or 4 of the loop above.”

**Platform-agnostic core.** One `AIAgent` class serves CLI, gateway, ACP, batch, and API server. Platform differences live in the entry point, not in the agent itself.[3](https://blakecrosley.com/guides/hermes#fn:3) This is why the same slash commands work in the terminal and in Telegram — they’re dispatched from a shared `COMMAND_REGISTRY` in `hermes_cli/commands.py`.[6](https://blakecrosley.com/guides/hermes#fn:7)

**The directory structure is the system.** Hermes stores everything under `~/.hermes/` (or `$HERMES_HOME` for non-default profiles):[4](https://blakecrosley.com/guides/hermes#fn:4)

```text
~/.hermes/
├── config.yaml        # Settings (model, terminal, TTS, compression, etc.)
├── .env               # API keys and secrets
├── auth.json          # OAuth provider credentials (Nous Portal, Codex, Anthropic)
├── SOUL.md            # Primary agent identity (slot #1 in system prompt)
├── memories/          # Persistent memory (MEMORY.md, USER.md)
├── skills/            # Bundled + agent-created + hub-installed skills
├── cron/              # Scheduled jobs
├── sessions/          # Gateway session state
└── logs/              # agent.log, gateway.log, errors.log (secrets auto-redacted)
```

Every file above has a specific role; none of them overlap. If you’re looking for “where does Hermes store X,” it’s one of these.

---

## Installation

The one-line installer is the path for 95% of users. It handles Python, uv, Node.js, ripgrep, ffmpeg, the repo clone, the virtual environment, and the global `hermes` command.[7](https://blakecrosley.com/guides/hermes#fn:8)

```bash
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
```

Works on Linux, macOS, WSL2, and Android/Termux (the installer auto-detects Termux and switches to a tested Android bundle).[7](https://blakecrosley.com/guides/hermes#fn:8) Native Windows is **not** supported — install WSL2 and run the command above from there.[7](https://blakecrosley.com/guides/hermes#fn:8)

After it finishes:

```bash
source ~/.bashrc
# or ~/.zshrc
hermes
# Start chatting
```

The only prerequisite is `git`. The installer auto-provisions Python 3.11 via `uv` (no sudo required), Node.js v22 (for browser automation and the WhatsApp bridge), ripgrep, and ffmpeg.[7](https://blakecrosley.com/guides/hermes#fn:8)

### Verify the install

```bash
hermes version
# Check version
hermes doctor
# Diagnose config/dependency issues
hermes status
# Show current configuration + auth state
hermes dump
# Copy-pasteable setup summary for debugging
```

`hermes doctor` tells you exactly what’s missing and how to fix it.[7](https://blakecrosley.com/guides/hermes#fn:8) `hermes dump` is the diagnostic command to paste into a GitHub issue or Discord thread when asking for help — it’s a plain-text summary of your entire setup with secrets redacted.[8](https://blakecrosley.com/guides/hermes#fn:9)

### Manual installation

If you need full control — custom Python version, specific extras, Nix/NixOS integration — the manual flow is documented step-by-step in the upstream installation guide.[7](https://blakecrosley.com/guides/hermes#fn:8) Key optional extras you can combine with `uv pip install -e ".[<extras>]"`:

| Extra           | What it adds                                                                  |
| --------------- | ----------------------------------------------------------------------------- |
| `all`           | Everything below                                                              |
| `messaging`     | Telegram & Discord gateway                                                    |
| `cron`          | Cron expression parsing                                                       |
| `cli`           | Terminal menu UI for setup wizard                                             |
| `modal`         | Modal cloud execution backend                                                 |
| `voice`         | CLI microphone input + audio playback                                         |
| `tts-premium`   | ElevenLabs premium voices                                                     |
| `honcho`        | AI-native memory (Honcho integration)                                         |
| `mcp`           | Model Context Protocol support                                                |
| `homeassistant` | Home Assistant integration                                                    |
| `acp`           | ACP editor integration support                                                |
| `slack`         | Slack messaging                                                               |
| `pty`           | PTY terminal support (interactive CLI tools)                                  |
| `dev`           | pytest & test utilities                                                       |
| `termux`        | Tested Android bundle (includes `cron`, `cli`, `pty`, `mcp`, `honcho`, `acp`) |

**Termux install command is different** — it uses `pip` with a constraints file, not `uv pip`:

```bash
python -m
pip install -e ".[termux]" -c constraints-termux.txt
```

This is because `.[all]` on Android pulls `faster-whisper` via the `voice` extra, which depends on `ctranslate2` wheels that aren’t published for Android.[7](https://blakecrosley.com/guides/hermes#fn:8)

---

## Authentication & Providers

Hermes supports ~19 first-class providers plus custom endpoints, and three distinct auth paths. Here is the whole auth surface, organized by path so you can find the one that matches what you have.

### The Three Auth Paths

Every provider in Hermes fits into one of three authentication patterns:

**Path 1 — API key in `.env`.** Put your key in `~/.hermes/.env` and Hermes reads it on startup. Used by OpenRouter, AI Gateway, z.ai/GLM, Kimi/Moonshot, MiniMax (and MiniMax China), Alibaba Cloud/DashScope, Kilo Code, OpenCode Zen, OpenCode Go, DeepSeek, Hugging Face, Google/Gemini, and most third-party providers.[2](https://blakecrosley.com/guides/hermes#fn:2)

**Path 2 — OAuth via `hermes model` or `hermes auth`.** Launches a device code flow, opens a browser, stores credentials in `~/.hermes/auth.json` (and can import existing credentials from tools like Claude Code or Codex CLI). Used by Nous Portal, OpenAI Codex (ChatGPT account), GitHub Copilot, and Anthropic (Claude Pro/Max).[2](https://blakecrosley.com/guides/hermes#fn:2)

**Path 3 — Custom endpoint in `config.yaml`.** For any OpenAI-compatible API — Ollama, vLLM, SGLang, llama.cpp, LM Studio, LiteLLM proxy, Together AI, Groq, Azure OpenAI, or your own self-hosted server. Configured once via `hermes model → Custom endpoint`, then persisted to `config.yaml`.[2](https://blakecrosley.com/guides/hermes#fn:2)

### The Full Provider Matrix

This is the complete list of first-class providers, with the exact setup flow for each.[2](https://blakecrosley.com/guides/hermes#fn:2)

| Provider                 | Auth path        | Setup                                                                                                                                                                                                                               |
| ------------------------ | ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Nous Portal**          | OAuth            | `hermes model` (OAuth login, subscription-based)                                                                                                                                                                                    |
| **OpenAI Codex**         | OAuth            | `hermes model` (ChatGPT device code, uses Codex models)                                                                                                                                                                             |
| **GitHub Copilot**       | OAuth or token   | `hermes model` (OAuth device code), or `COPILOT_GITHUB_TOKEN` / `GH_TOKEN` / `gh auth token`                                                                                                                                        |
| **GitHub Copilot ACP**   | Local subprocess | `hermes model` (requires `copilot` CLI in PATH + `copilot login`)                                                                                                                                                                   |
| **Anthropic**            | OAuth or API key | `hermes model` (prefers Claude Code credentials), or `ANTHROPIC_API_KEY`, or `ANTHROPIC_TOKEN` setup-token                                                                                                                          |
| **OpenRouter**           | API key          | `OPENROUTER_API_KEY` in `~/.hermes/.env`                                                                                                                                                                                            |
| **AI Gateway (Vercel)**  | API key          | `AI_GATEWAY_API_KEY` in `~/.hermes/.env` (provider: `ai-gateway`)                                                                                                                                                                   |
| **z.ai / GLM (ZhipuAI)** | API key          | `GLM_API_KEY` in `~/.hermes/.env` (provider: `zai`)                                                                                                                                                                                 |
| **Kimi / Moonshot**      | API key          | `KIMI_API_KEY` in `~/.hermes/.env` (provider: `kimi-coding`)                                                                                                                                                                        |
| **MiniMax (global)**     | API key          | `MINIMAX_API_KEY` in `~/.hermes/.env` (provider: `minimax`)                                                                                                                                                                         |
| **MiniMax China**        | API key          | `MINIMAX_CN_API_KEY` in `~/.hermes/.env` (provider: `minimax-cn`)                                                                                                                                                                   |
| **Alibaba Cloud (Qwen)** | API key          | `DASHSCOPE_API_KEY` in `~/.hermes/.env` (provider: `alibaba`, aliases: `dashscope`, `qwen`)                                                                                                                                         |
| **Kilo Code**            | API key          | `KILOCODE_API_KEY` in `~/.hermes/.env` (provider: `kilocode`)                                                                                                                                                                       |
| **OpenCode Zen**         | API key          | `OPENCODE_ZEN_API_KEY` in `~/.hermes/.env` (provider: `opencode-zen`)                                                                                                                                                               |
| **OpenCode Go**          | API key          | `OPENCODE_GO_API_KEY` in `~/.hermes/.env` (provider: `opencode-go`)                                                                                                                                                                 |
| **DeepSeek**             | API key          | `DEEPSEEK_API_KEY` in `~/.hermes/.env` (provider: `deepseek`)                                                                                                                                                                       |
| **Hugging Face**         | API key          | `HF_TOKEN` in `~/.hermes/.env` (provider: `huggingface`, alias: `hf`)                                                                                                                                                               |
| **Google / Gemini**      | API key          | `GOOGLE_API_KEY` or `GEMINI_API_KEY` in `~/.hermes/.env` (provider: `gemini`)                                                                                                                                                       |
| **xAI (Grok)**           | Native provider  | First-class provider with direct API access and model catalog (v0.9.0+). Auto-enables prompt caching via `x-grok-conv-id` header.[2](https://blakecrosley.com/guides/hermes#fn:2)[16](https://blakecrosley.com/guides/hermes#fn:20) |
| **Xiaomi MiMo**          | Native provider  | First-class provider with setup wizard and model catalog. Free MiMo v2 Pro on Nous Portal for auxiliary tasks (v0.9.0+).[16](https://blakecrosley.com/guides/hermes#fn:20)[15](https://blakecrosley.com/guides/hermes#fn:19)        |
| **Google AI Studio**     | API key          | `GOOGLE_API_KEY` or `GEMINI_API_KEY` in `~/.hermes/.env`. Direct Gemini access with auto-detected context lengths via models.dev registry (v0.8.0+).[15](https://blakecrosley.com/guides/hermes#fn:19)                              |
| **Qwen**                 | OAuth            | OAuth provider with portal request support (v0.8.0+).[15](https://blakecrosley.com/guides/hermes#fn:19)                                                                                                                             |
| **Custom endpoint**      | config.yaml      | `hermes model` → “Custom endpoint” (saved in `config.yaml`)                                                                                                                                                                         |

### Anthropic: Three Auth Methods

Anthropic gets its own section because Hermes supports three distinct paths into Claude, and picking the right one matters. From the upstream docs:[2](https://blakecrosley.com/guides/hermes#fn:2)

```
# Method 1: API key (pay-per-token)

export ANTHROPIC_API_KEY=***
hermes chat --provider anthropic --model claude-sonnet-4-6
# Method 2: OAuth through
hermes model (preferred)
# Uses Claude Code's credential store when available
hermes model
# Method 3: Manual setup-token (fallback/legacy)
export ANTHROPIC_TOKEN=***
hermes chat --provider anthropic
# Auto-detect Claude Code credentials
hermes chat --provider anthropic
# reads Claude Code files automatically
```

When you choose Anthropic OAuth through `hermes model`, Hermes prefers Claude Code’s own credential store over copying the token into `~/.hermes/.env`. That keeps refreshable Claude credentials refreshable.[2](https://blakecrosley.com/guides/hermes#fn:2) If you already use Claude Code on the same machine, this is the cleanest path.

To pin Anthropic permanently in `config.yaml`:

```yaml
model:   provider: "anthropic"   default: "claude-sonnet-4-6"
```

`--provider claude` and `--provider claude-code` also work as shorthand for `--provider anthropic`.[2](https://blakecrosley.com/guides/hermes#fn:2)

### GitHub Copilot: Two Modes

Copilot is supported in two modes: direct Copilot API (recommended) and Copilot ACP (which spawns the local Copilot CLI as a subprocess).[2](https://blakecrosley.com/guides/hermes#fn:2)

```
# Direct Copilot API

hermes chat --provider copilot --model gpt-5.4
# Copilot ACP (requires the Copilot CLI in PATH + an existing copilot login)
hermes chat --provider copilot-acp --model copilot-acp
```

Authentication is checked in this order, per the upstream docs:[2](https://blakecrosley.com/guides/hermes#fn:2) 1. `COPILOT_GITHUB_TOKEN` environment variable 2. `GH_TOKEN` environment variable 3. `GITHUB_TOKEN` environment variable 4. `gh auth token` CLI fallback 5. OAuth device code login via `hermes model`

**Token type matters.** The Copilot API does not support classic Personal Access Tokens (`ghp_*`). Supported types are OAuth tokens (`gho_*`), fine-grained PATs (`github_pat_*` with `Copilot Requests` permission), and GitHub App tokens (`ghu_*`). If your `gh auth token` returns a `ghp_*` token, use `hermes model` to authenticate via OAuth instead.[2](https://blakecrosley.com/guides/hermes#fn:2)

### Chinese AI Providers (First-Class Support)

Hermes has built-in support for z.ai/GLM, Kimi/Moonshot, MiniMax (global + China endpoints), and Alibaba Cloud with dedicated provider IDs.[2](https://blakecrosley.com/guides/hermes#fn:2)

```
# z.ai / ZhipuAI GLM

hermes chat --provider zai --model glm-5
# Requires: GLM_API_KEY
# Kimi / Moonshot AI
hermes chat --provider kimi-coding --model kimi-for-coding
# Requires: KIMI_API_KEY
# MiniMax (global)
hermes chat --provider minimax --model MiniMax-M2.7
# Requires: MINIMAX_API_KEY
# MiniMax (China)
hermes chat --provider minimax-cn --model MiniMax-M2.7
# Requires: MINIMAX_CN_API_KEY
# Alibaba Cloud / DashScope (Qwen)
hermes chat --provider alibaba --model qwen3.5-plus
# Requires: DASHSCOPE_API_KEY
```

Base URLs can be overridden with `GLM_BASE_URL`, `KIMI_BASE_URL`, `MINIMAX_BASE_URL`, `MINIMAX_CN_BASE_URL`, or `DASHSCOPE_BASE_URL` environment variables.[2](https://blakecrosley.com/guides/hermes#fn:2)

**Z.AI auto-detects the endpoint.** When using the z.ai/GLM provider, Hermes probes multiple endpoints (global, China, coding variants) to find one that accepts your API key. The working endpoint is cached automatically — no `GLM_BASE_URL` needed for most users.[2](https://blakecrosley.com/guides/hermes#fn:2)

**xAI (Grok) automatically enables prompt caching.** When the base URL contains `x.ai`, Hermes sends the `x-grok-conv-id` header with every request to route to the same server within a conversation session, reusing cached system prompts and history.[2](https://blakecrosley.com/guides/hermes#fn:2) Automatic; no config needed.

### The `hermes auth` Command

`hermes auth` is the credential management command for pools and OAuth credentials.[6](https://blakecrosley.com/guides/hermes#fn:7)

```bash
hermes auth
# Interactive wizard
hermes auth list
# Show all credential pools
hermes auth list openrouter
# Show one provider's pool
hermes auth add openrouter --api-key sk-or-v1-xxx
hermes auth add anthropic --type oauth
hermes auth remove openrouter 2
# Remove by index
hermes auth reset openrouter
# Clear cooldowns
```

Credential pools are how you rotate multiple API keys or OAuth tokens for the same provider — useful for distributing rate limits across multiple keys without changing code.[6](https://blakecrosley.com/guides/hermes#fn:7) The legacy `hermes login` / `hermes logout` commands have been removed; use `hermes auth` instead.[6](https://blakecrosley.com/guides/hermes#fn:7)

### Custom & Self-Hosted Endpoints

Hermes works with any OpenAI-compatible API endpoint. If a server implements `/v1/chat/completions`, you can point Hermes at it.[2](https://blakecrosley.com/guides/hermes#fn:2)

**Interactive setup (recommended):**

```bash
hermes model
# Select "Custom endpoint (self-hosted / VLLM / etc.)"
# Enter: API base URL, API key, Model name
```

**Manual `config.yaml`:**

```yaml
model:   default: your-model-name   provider: custom   base_url: http://localhost:8000/v1   api_key: your-key-or-leave-empty-for-local
```

Both approaches persist to `config.yaml`, which is the single source of truth for main-model, provider, and base URL.[2](https://blakecrosley.com/guides/hermes#fn:2) The legacy env vars `OPENAI_BASE_URL` and `LLM_MODEL` are **no longer read for main-model configuration** — use `hermes model` or edit `config.yaml` directly.[2](https://blakecrosley.com/guides/hermes#fn:2) (`OPENAI_BASE_URL` + `OPENAI_API_KEY` are still honored as a fallback for the auxiliary `provider: "main"` routing path, so don’t delete them blindly if you’re using them there.)[4](https://blakecrosley.com/guides/hermes#fn:4)

**Switching custom endpoints mid-session:**

```bash
/model custom:qwen-2.5
# Custom endpoint with explicit model
/model custom
# Auto-detect the model from the endpoint
/model custom:local:qwen-2.5
# Named custom provider "local"
/model custom:work:llama3
# Named custom provider "work"
/model openrouter:claude-sonnet-4
# Back to a cloud provider
```

`/model custom` (bare, no model name) queries your endpoint’s `/v1/models` API and auto-selects the model if exactly one is loaded — useful for local servers running a single model.[2](https://blakecrosley.com/guides/hermes#fn:2)

### Local LLM Servers (Setup Templates)

The upstream docs have full setup guides for Ollama, vLLM, SGLang, llama.cpp, and LM Studio. Here are the key commands you’ll actually run. Each is designed to produce a working endpoint that Hermes can point at.[2](https://blakecrosley.com/guides/hermes#fn:2)

**Ollama** — easiest local path, zero config:

```bash
ollama pull qwen2.5-coder:32b OLLAMA_CONTEXT_LENGTH=32768
ollama serve
# Raise from 4k default
hermes model
# Custom endpoint → http://localhost:11434/v1 → qwen2.5-coder:32b
```

**Critical Ollama gotcha:** Ollama defaults to very low context lengths (4,096 tokens under 24GB VRAM). You must raise it via `OLLAMA_CONTEXT_LENGTH` or a Modelfile — the OpenAI-compatible API does **not** accept context length from the client, so Hermes cannot set it for you.[2](https://blakecrosley.com/guides/hermes#fn:2) For agent use, set at least 16k–32k.

**vLLM** — high-performance GPU serving:

```bash
pip install vllm vllm serve meta-llama/Llama-3.1-70B-Instruct \
  --port 8000 \
  --max-model-len 65536 \
  --tensor-parallel-size 2 \
  --enable-auto-tool-choice \
  --tool-call-parser
hermes
```

Tool calling requires `--enable-auto-tool-choice` and `--tool-call-parser <name>`. Supported parsers: `hermes` (Qwen 2.5, Hermes 2/3), `llama3_json`, `mistral`, `deepseek_v3`, `deepseek_v31`, `xlam`, `pythonic`. Without these flags, tool calls will come back as plain text.[2](https://blakecrosley.com/guides/hermes#fn:2)

**SGLang** — fast serving with RadixAttention for KV cache reuse:

```bash
pip install "sglang[all]"
python -m sglang.launch_server \
  --model meta-llama/Llama-3.1-70B-Instruct \
  --port 30000 \
  --context-length 65536 \
  --tp 2 \
  --tool-call-parser qwen
```

**SGLang gotcha:** Default `max_tokens` is 128. Set `--default-max-tokens` on the server or configure `model.max_tokens` in `config.yaml` if responses get cut off.[2](https://blakecrosley.com/guides/hermes#fn:2)

**llama.cpp / llama-server** — CPU and Apple Silicon Metal:

```bash
./build/bin/llama-server \
  --jinja -fa \
  -c 32768 \
  -ngl 99 \
  -m models/qwen2.5-coder-32b-instruct-Q4_K_M.gguf \
  --port 8080 --host 0.0.0.0
```

**`--jinja` is required for tool calling.** Without it, llama-server ignores the `tools` parameter entirely and the model tries to call tools by writing JSON in its response text — which Hermes can’t parse as actual tool calls.[2](https://blakecrosley.com/guides/hermes#fn:2)

**LM Studio** — desktop app with GUI:

Start the server from the LM Studio app (Developer tab → Start Server), or via CLI: `lms server start` (starts on port 1234) and `lms load qwen2.5-coder --context-length 32768`.[2](https://blakecrosley.com/guides/hermes#fn:2) Then point `hermes model` at `http://localhost:1234/v1`.

**Critical LM Studio gotcha:** LM Studio reads context length from model metadata, but many GGUF models report 2048 or 4096 defaults. Always set context length explicitly in the LM Studio model settings — click the gear icon next to the model picker, set “Context Length” to at least 16384 (preferably 32768), and reload the model.[2](https://blakecrosley.com/guides/hermes#fn:2)

### Named Custom Providers

If you work with multiple custom endpoints (a local dev server and a remote GPU server, for example), define them as named custom providers in `config.yaml`:[2](https://blakecrosley.com/guides/hermes#fn:2)

```yaml
custom_providers:   - name: local     base_url: http://localhost:8080/v1     # api_key omitted — Hermes uses "no-key-required" for keyless local servers   - name: work     base_url: https://gpu-server.internal.corp/v1     api_key: corp-api-key     api_mode: chat_completions      # optional, auto-detected from URL   - name: anthropic-proxy     base_url: https://proxy.example.com/anthropic     api_key: proxy-key     api_mode: anthropic_messages    # for Anthropic-compatible proxies
```

Then switch between them mid-session with the triple syntax:

```bash
/model custom:local:qwen-2.5
/model custom:work:llama3-70b
/model custom:anthropic-proxy:claude-sonnet-4
```

You can also select named custom providers from the interactive `hermes model` menu.[2](https://blakecrosley.com/guides/hermes#fn:2)

### Context Length Detection

Two settings get confused constantly, per the upstream docs:[2](https://blakecrosley.com/guides/hermes#fn:2)

- **`context_length`** — the total context window (combined input + output token budget, e.g. 1,000,000 for Claude Opus 4.7 or 200,000 for Sonnet 4.6). Hermes uses this to decide when to compress history.
- **`model.max_tokens`** — the output cap (max tokens the model may generate in a single response). Unrelated to history length.

Set `context_length` when auto-detection gets the window size wrong:

```yaml
model:   default: "qwen3.5:9b"   base_url: "http://localhost:8080/v1"   context_length: 131072      # tokens
```

Hermes uses a multi-source resolution chain to detect context windows: config override → custom provider per-model → persistent cache → endpoint `/models` → Anthropic `/v1/models` → OpenRouter API → Nous Portal → `models.dev` (community-maintained registry for 3800+ models) → fallback defaults (128K).[2](https://blakecrosley.com/guides/hermes#fn:2) The system is provider-aware, so the same model can have different context limits depending on who serves it (e.g., `claude-opus-4.6` is 1M on Anthropic direct but 128K on GitHub Copilot).[2](https://blakecrosley.com/guides/hermes#fn:2)

### Provider Rotation & Fallback

**Credential pools.** When you have multiple API keys for the same provider, configure a rotation strategy via `hermes auth`. This is how you distribute rate limits across multiple keys.[6](https://blakecrosley.com/guides/hermes#fn:7)

**Fallback model.** Configure a backup `provider:model` that Hermes switches to automatically when your primary model fails (rate limits, server errors, auth failures):[2](https://blakecrosley.com/guides/hermes#fn:2)

```yaml
fallback_model:   provider: openrouter            # required   model: anthropic/claude-sonnet-4  # required   # base_url: http://localhost:8000/v1    # optional, for custom endpoints   # api_key_env: MY_CUSTOM_KEY           # optional, env var name
```

The fallback swaps model and provider mid-session without losing your conversation. It fires at most once per session.[2](https://blakecrosley.com/guides/hermes#fn:2) Supported providers for fallback: `openrouter`, `nous`, `openai-codex`, `copilot`, `copilot-acp`, `anthropic`, `huggingface`, `zai`, `kimi-coding`, `minimax`, `minimax-cn`, `deepseek`, `ai-gateway`, `opencode-zen`, `opencode-go`, `kilocode`, `alibaba`, `custom`.[2](https://blakecrosley.com/guides/hermes#fn:2)

### Auxiliary Models

Hermes uses lightweight “auxiliary” models for side tasks: image analysis, web page summarization, browser screenshot analysis, dangerous command approval classification, context compression, session search summarization, skill matching, MCP tool dispatch, and memory flush.[4](https://blakecrosley.com/guides/hermes#fn:4) By default these use Gemini Flash via auto-detection (OpenRouter → Nous → Codex).

**You can configure which model and provider each auxiliary task uses.** Every auxiliary slot uses the same three knobs: `provider`, `model`, `base_url`.[4](https://blakecrosley.com/guides/hermes#fn:4)

```yaml
auxiliary:   vision:     provider: "auto"                # "auto", "openrouter", "nous", "codex", "main", etc.     model: ""                       # e.g. "openai/gpt-4o", "google/gemini-2.5-flash"     base_url: ""                    # Custom OpenAI-compatible endpoint     api_key: ""                     # Falls back to OPENAI_API_KEY     timeout: 30     download_timeout: 30   web_extract:     provider: "auto"     model: ""     timeout: 360   approval:     provider: "auto"     model: ""     timeout: 30   compression:     timeout: 120   session_search: { provider: "auto", model: "", timeout: 30 }   skills_hub:    { provider: "auto", model: "", timeout: 30 }   mcp:           { provider: "auto", model: "", timeout: 30 }   flush_memories:{ provider: "auto", model: "", timeout: 30 }
```

The `"main"` provider option means “use whatever provider my main agent uses” — valid **only** inside `auxiliary:`, `compression:`, and `fallback_model:` configs. It is **not** valid for your top-level `model.provider` setting. If you use a custom OpenAI-compatible endpoint as your main model, set `provider: custom` in your `model:` section.[4](https://blakecrosley.com/guides/hermes#fn:4)

**Why this matters:** if you only configured Anthropic OAuth (no OpenRouter key), your vision, web summarization, and compression will degrade or fail because the default auxiliary fallback chain tries OpenRouter first. Add an `OPENROUTER_API_KEY` for auxiliary tasks, or reconfigure each auxiliary slot to use your main provider:

```yaml
auxiliary:   vision:     provider: "main"   web_extract:     provider: "main"
```

This is the single most common “my features silently don’t work” gotcha for new Hermes users.

---

## Configuration System

Hermes has a layered configuration system. Understanding the precedence is essential because higher layers override lower ones, and one of the layers is a global provider registry you can’t see in `config.yaml`.

### Config File Layout

Per the upstream docs, these are the files that make up a Hermes configuration:[4](https://blakecrosley.com/guides/hermes#fn:4)

```text
~/.hermes/
├── config.yaml       # All settings (model, terminal, TTS, compression, memory, toolsets, ...)
├── .env              # Secrets (API keys, bot tokens, passwords)
├── auth.json         # OAuth provider credentials (Nous Portal, Codex, Anthropic)
├── SOUL.md           # Primary agent identity (slot #1 in system prompt)
├── memories/         # Persistent memory (MEMORY.md, USER.md)
├── skills/           # Bundled + agent-created + hub-installed skills
├── cron/             # Scheduled jobs
├── sessions/         # Gateway session state
└── logs/             # agent.log, gateway.log, errors.log (secrets auto-redacted)
```

**`config.yaml` vs `.env` — when both are set, `config.yaml` wins for non-secret settings.**[4](https://blakecrosley.com/guides/hermes#fn:4) The rule is: - **Secrets** (API keys, bot tokens, passwords) → `.env` - **Everything else** (model, terminal backend, compression settings, memory limits, toolsets) → `config.yaml`

Secrets can be referenced from `config.yaml` using shell-style interpolation:[4](https://blakecrosley.com/guides/hermes#fn:4)

```yaml
auxiliary:   vision:     api_key: ${GOOGLE_API_KEY}     base_url: ${CUSTOM_VISION_URL}   delegation:     api_key: ${DELEGATION_KEY}
```

### Managing Configuration

```bash
hermes config
# View current configuration
hermes config show
# Same as above
hermes config edit
# Open config.yaml in your editor
hermes config set KEY VAL
# Set a specific value
hermes config path
# Print the config file path
hermes config env-path
# Print the .env file path
hermes config check
# Check for missing options (after updates)
hermes config migrate
# Interactively add missing options
```

Examples:[4](https://blakecrosley.com/guides/hermes#fn:4)

```bash
hermes config set model anthropic/claude-opus-4
hermes config set terminal.backend docker
hermes config set OPENROUTER_API_KEY sk-or-...
# Saves to .env
```

`hermes config check` and `hermes config migrate` are the commands to run after every `hermes update` — they catch newly added config options that your file doesn’t yet have.[6](https://blakecrosley.com/guides/hermes#fn:7)

### Configuration Precedence

Hermes loads configuration from several sources. When multiple sources set the same value, the higher-priority source wins:[4](https://blakecrosley.com/guides/hermes#fn:4)

1. **CLI arguments** — `hermes chat --model anthropic/claude-sonnet-4` (per-invocation override)
2. **Environment variables** — applied at process startup
3. **`config.yaml`** — the primary settings file
4. **`.env`** — secrets only
5. **Built-in defaults** — applied when nothing else sets a value

CLI flags always win for that single invocation. `config.yaml` is the long-term source of truth.

### Profiles — Multiple Isolated Hermes Instances

Profiles give you multiple isolated Hermes instances, each with its own config, sessions, skills, memory, and gateway PID. This is how you run “work Hermes” and “personal Hermes” side-by-side without either seeing the other’s state.[6](https://blakecrosley.com/guides/hermes#fn:7)

```bash
hermes profile list
hermes profile create work --clone
# Clone from current profile
hermes profile use work
# Set sticky default
hermes profile alias work --name h-work
# Create wrapper script
hermes profile
export work -o work-backup.tar.gz
hermes profile import work-backup.tar.gz --name restored
hermes -p work chat -q "Hello from work profile"
# One-off without switching
```

Each profile gets its own `HERMES_HOME` (`~/.hermes-<name>/` by default), so multiple profiles can run the gateway concurrently without stepping on each other.[6](https://blakecrosley.com/guides/hermes#fn:7)[3](https://blakecrosley.com/guides/hermes#fn:3)

---

## CLI Commands

This section is the practitioner’s reference to top-level CLI commands. For the authoritative code-derived reference, see the upstream [CLI Commands Reference](https://hermes-agent.nousresearch.com/docs/reference/cli-commands).[6](https://blakecrosley.com/guides/hermes#fn:7)

### Global Options

```bash
hermes [global-options] <command> [subcommand/options]
```

| Option                               | Description                                         |
| ------------------------------------ | --------------------------------------------------- |
| `--version`, `-V`                    | Show version and exit                               |
| `--profile <name>`, `-p <name>`      | Select which Hermes profile to use                  |
| `--resume <session>`, `-r <session>` | Resume a session by ID or title                     |
| `--continue [name]`, `-c [name]`     | Resume the most recent session (or match a title)   |
| `--worktree`, `-w`                   | Start in an isolated git worktree                   |
| `--yolo`                             | Bypass dangerous-command approval prompts           |
| `--pass-session-id`                  | Include the session ID in the agent’s system prompt |

### Top-Level Commands

| Command              | Purpose                                                                                                                               |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `hermes chat`        | Interactive or one-shot chat                                                                                                          |
| `hermes model`       | Interactively choose default provider and model                                                                                       |
| `hermes gateway`     | Run or manage the messaging gateway                                                                                                   |
| `hermes setup`       | Interactive setup wizard                                                                                                              |
| `hermes auth`        | Manage credentials — add, list, remove, reset, set strategy                                                                           |
| `hermes status`      | Show agent, auth, and platform status                                                                                                 |
| `hermes cron`        | Inspect and tick the cron scheduler                                                                                                   |
| `hermes webhook`     | Manage dynamic webhook subscriptions                                                                                                  |
| `hermes doctor`      | Diagnose config and dependency issues                                                                                                 |
| `hermes dump`        | Copy-pasteable setup summary for support/debugging                                                                                    |
| `hermes logs`        | View, tail, and filter agent/gateway/error logs                                                                                       |
| `hermes config`      | Show, edit, migrate, query configuration                                                                                              |
| `hermes pairing`     | Approve or revoke messaging pairing codes                                                                                             |
| `hermes skills`      | Browse, install, publish, audit skills                                                                                                |
| `hermes honcho`      | Manage Honcho cross-session memory                                                                                                    |
| `hermes memory`      | Configure external memory provider                                                                                                    |
| `hermes acp`         | Run Hermes as an ACP server (editor integration)                                                                                      |
| `hermes mcp`         | Manage MCP server config; run Hermes as MCP server                                                                                    |
| `hermes plugins`     | Manage plugins                                                                                                                        |
| `hermes tools`       | Configure enabled tools per platform                                                                                                  |
| `hermes sessions`    | Browse, export, prune, delete sessions                                                                                                |
| `hermes insights`    | Show token/cost/activity analytics                                                                                                    |
| `hermes claw`        | OpenClaw migration helpers                                                                                                            |
| `hermes profile`     | Manage profiles (multiple isolated instances)                                                                                         |
| `hermes completion`  | Print shell completion scripts (bash/zsh)                                                                                             |
| `hermes whatsapp`    | Configure and pair the WhatsApp bridge                                                                                                |
| `hermes version`     | Print version information                                                                                                             |
| `hermes update`      | Pull latest code and reinstall dependencies                                                                                           |
| `hermes uninstall`   | Remove Hermes from the system (`--full` also deletes config/data)                                                                     |
| `hermes backup`      | Full backup of config, sessions, skills, and memory (v0.9.0+)[16](https://blakecrosley.com/guides/hermes#fn:20)                       |
| `hermes import`      | Restore from a backup archive — migrate between machines or roll back (v0.9.0+)[16](https://blakecrosley.com/guides/hermes#fn:20)     |
| `hermes dashboard`   | Launch the local web dashboard for browser-based agent management (v0.9.0+)[16](https://blakecrosley.com/guides/hermes#fn:20)         |
| `hermes debug share` | Upload a full debug report to a pastebin for sharing when troubleshooting (v0.9.0+)[16](https://blakecrosley.com/guides/hermes#fn:20) |

### `hermes chat` — The Main Entry Point

`hermes` with no arguments drops you into interactive chat. `hermes chat` is the explicit form with options:[6](https://blakecrosley.com/guides/hermes#fn:7)

```bash
hermes chat -q "Summarize the latest PRs"
# One-shot, non-interactive
hermes chat --provider openrouter --model anthropic/claude-sonnet-4.6
hermes chat --toolsets web,terminal,skills
# Enable specific toolsets
hermes chat --quiet -q "Return only JSON"
# Programmatic mode
hermes chat --worktree -q "Review repo and open a PR"
```

Key options:

| Option                   | Description                                                                                         |
| ------------------------ | --------------------------------------------------------------------------------------------------- |
| `-q`, `--query "..."`    | One-shot, non-interactive prompt                                                                    |
| `-m`, `--model <model>`  | Override the model for this run                                                                     |
| `-t`, `--toolsets <csv>` | Enable a comma-separated set of toolsets                                                            |
| `--provider <provider>`  | Force a provider (see [full list](https://blakecrosley.com/guides/hermes#the-full-provider-matrix)) |
| `-s`, `--skills <name>`  | Preload one or more skills for this session                                                         |
| `-v`, `--verbose`        | Verbose output                                                                                      |
| `-Q`, `--quiet`          | Programmatic mode (no banner, spinner, previews)                                                    |
| `--resume <session>`     | Resume a session directly from `chat`                                                               |
| `--worktree`             | Create an isolated git worktree                                                                     |
| `--checkpoints`          | Enable filesystem checkpoints before destructive changes                                            |
| `--yolo`                 | Skip approval prompts                                                                               |
| `--source <tag>`         | Session source tag (default: `cli`; use `tool` for integrations)                                    |
| `--max-turns <N>`        | Max tool-calling iterations per turn (default: 90)                                                  |

### `hermes setup` — Full Wizard

Runs the full setup wizard or jumps into one section:[6](https://blakecrosley.com/guides/hermes#fn:7)

```bash
hermes setup
# Full wizard
hermes setup model
# Provider and model only
hermes setup terminal
# Terminal backend only
hermes setup gateway
# Messaging platforms only
hermes setup tools
# Tool enable/disable per platform
hermes setup agent
# Agent behavior only
hermes setup --non-interactive
hermes setup --reset
# Reset config to defaults before setup
```

### `hermes logs` — Structured Log Querying

`hermes logs` is more powerful than `tail -f` on the log files because it supports filtering by level, session ID, and time range simultaneously.[6](https://blakecrosley.com/guides/hermes#fn:7)

```bash
hermes logs
# Last 50 lines of agent.log
hermes logs -f
# Follow in real time
hermes logs gateway -n 100
# Last 100 lines of gateway.log
hermes logs --level WARNING --since 1h
# Warnings from the last hour
hermes logs --session abc123
# Filter by session ID substring
hermes logs errors --since 30m -f
# Follow errors.log from 30m ago
hermes logs list
# List all log files with sizes
```

Log files live in `~/.hermes/logs/`:[6](https://blakecrosley.com/guides/hermes#fn:7) - `agent.log` — all agent activity (API calls, tool dispatch, session lifecycle, INFO+) - `errors.log` — warnings and errors only (a filtered subset of agent.log) - `gateway.log` — messaging gateway activity (platform connections, dispatch, webhooks)

Rotation is automatic via Python’s `RotatingFileHandler` — look for `agent.log.1`, `agent.log.2`, etc.[6](https://blakecrosley.com/guides/hermes#fn:7)

### `hermes doctor` — Diagnostics

`hermes doctor [--fix]` is the first command to run when something is wrong. It checks config validity, dependency presence, API key availability, service status, and can attempt automatic repairs with `--fix`.[6](https://blakecrosley.com/guides/hermes#fn:7)

For sharing diagnostics with someone else, use `hermes dump` — it produces a compact plain-text summary with redacted API keys, ready to paste into a GitHub issue or Discord thread.[6](https://blakecrosley.com/guides/hermes#fn:7)

---

## Slash Commands

Slash commands run inside an active chat session (CLI or messaging platform). They’re dispatched from a shared `COMMAND_REGISTRY` in `hermes_cli/commands.py`, which is why most commands work identically across surfaces.[9](https://blakecrosley.com/guides/hermes#fn:10)

### Session Control

| Command                              | Description                                                                                                                                                                                                                                     |
| ------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/new` (alias `/reset`)              | Start a new session                                                                                                                                                                                                                             |
| `/clear`                             | Clear screen + start new session                                                                                                                                                                                                                |
| `/history`                           | Show conversation history                                                                                                                                                                                                                       |
| `/save`                              | Save the current conversation                                                                                                                                                                                                                   |
| `/retry`                             | Retry the last message                                                                                                                                                                                                                          |
| `/undo`                              | Remove the last user/assistant exchange                                                                                                                                                                                                         |
| `/title <name>`                      | Set a title for the current session                                                                                                                                                                                                             |
| `/compress`                          | Manually compress conversation context                                                                                                                                                                                                          |
| `/rollback [number]`                 | List or restore filesystem checkpoints                                                                                                                                                                                                          |
| `/stop`                              | Kill all running background processes                                                                                                                                                                                                           |
| `/queue <prompt>`                    | Queue a prompt for the next turn. **Gotcha:** `/q` is claimed by both `/queue` and `/quit`; last registration wins and `/q` resolves to `/quit` in practice — always type `/queue` explicitly.[9](https://blakecrosley.com/guides/hermes#fn:10) |
| `/resume [name]`                     | Resume a previously-named session                                                                                                                                                                                                               |
| `/statusbar` (alias `/sb`)           | Toggle context/model status bar                                                                                                                                                                                                                 |
| `/background <prompt>` (alias `/bg`) | Run a prompt in a separate background session                                                                                                                                                                                                   |
| `/btw <question>`                    | Ephemeral side question (no tools, not persisted)                                                                                                                                                                                               |
| `/plan [request]`                    | Load the bundled `plan` skill to write a plan instead of executing                                                                                                                                                                              |
| `/branch [name]` (alias `/fork`)     | Branch the current session                                                                                                                                                                                                                      |

### Configuration & Model

| Command               | Description                                                                                                                        |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | --- | -------- | --------------------- |
| `/config`             | Show current configuration                                                                                                         |
| `/model [model-name]` | Show or change the current model                                                                                                   |
| `/provider`           | Show available providers and current provider                                                                                      |
| `/personality [name]` | Set a personality overlay                                                                                                          |
| `/verbose`            | Cycle tool progress display                                                                                                        |
| `/reasoning`          | Manage reasoning effort and display                                                                                                |
| `/skin`               | Show or change display skin/theme                                                                                                  |
| `/voice [on           | off                                                                                                                                | tts | status]` | Toggle CLI voice mode |
| `/yolo`               | Toggle YOLO mode (skip approval prompts)                                                                                           |
| `/fast`               | Toggle Fast Mode — priority processing for OpenAI and Anthropic models (v0.9.0+)[16](https://blakecrosley.com/guides/hermes#fn:20) |
| `/debug`              | Quick diagnostics across all platforms (v0.9.0+)[16](https://blakecrosley.com/guides/hermes#fn:20)                                 |

The `/model` command is the workhorse for mid-session provider switching:[9](https://blakecrosley.com/guides/hermes#fn:10)

```bash
/model
# Show current model and options
/model claude-sonnet-4
# Switch model (auto-detect provider)
/model zai:glm-5
# Switch provider:model
/model custom:qwen-2.5
# Use model on custom endpoint
/model custom
# Auto-detect model from custom endpoint
/model custom:local:qwen-2.5
# Named custom provider
/model openrouter:anthropic/claude-sonnet-4
# Back to cloud
```

### Tools, Skills & Info

| Command            | Description                                |
| ------------------ | ------------------------------------------ | ------------------ | ------------------------------------ |
| `/tools [list      | disable                                    | enable] [name...]` | Manage tools for the current session |
| `/toolsets`        | List available toolsets                    |
| `/browser [connect | disconnect                                 | status]`           | Manage local Chrome CDP connection   |
| `/skills`          | Search, install, inspect, or manage skills |
| `/cron`            | Manage scheduled tasks                     |
| `/reload-mcp`      | Reload MCP servers from config.yaml        |
| `/plugins`         | List installed plugins                     |
| `/help`            | Show all commands                          |
| `/usage`           | Show token usage, cost, duration           |
| `/insights`        | Show usage analytics (last 30 days)        |
| `/platforms`       | Show messaging platform status             |
| `/profile`         | Show active profile name and home          |

### Dynamic Skill Slash Commands

Every installed skill is automatically exposed as a slash command:[9](https://blakecrosley.com/guides/hermes#fn:10)

```bash
/gif-search funny cats
/axolotl help me fine-tune Llama 3 on my dataset
/github-pr-workflow create a PR for the auth refactor
/excalidraw
# Just the skill name loads it and lets the agent ask what you need
```

You can also define **quick commands** in `config.yaml` that alias a short name to a longer prompt:[9](https://blakecrosley.com/guides/hermes#fn:10)

```yaml
quick_commands:
  review: "Review my latest git diff and suggest improvements"
  deploy: "Run the deployment script at scripts/deploy.sh and verify the output"
  morning: "Check my calendar, unread emails, and summarize today's priorities"
```

Then type `/review`, `/deploy`, or `/morning` in the CLI.

### Prefix Matching

Commands support prefix matching: typing `/h` resolves to `/help`, `/mod` resolves to `/model`. When a prefix is ambiguous, the first registration in registry order wins. Full command names and registered aliases always take priority over prefix matches.[9](https://blakecrosley.com/guides/hermes#fn:10)

### Messaging-Specific Commands

Some commands only work on messaging platforms (Telegram, Discord, Slack, WhatsApp, Signal, Email, Home Assistant):[9](https://blakecrosley.com/guides/hermes#fn:10)

- `/status` — show session info
- `/sethome` (alias `/set-home`) — mark the current chat as platform home
- `/approve [session|always]` — approve a pending dangerous command
- `/deny` — reject a pending dangerous command
- `/update` — update Hermes Agent to latest
- `/commands [page]` — browse all commands and skills (paginated)

And some are CLI-only: `/skin`, `/tools`, `/toolsets`, `/browser`, `/config`, `/cron`, `/skills`, `/platforms`, `/paste`, `/statusbar`, `/plugins`.[9](https://blakecrosley.com/guides/hermes#fn:10)

---

## Tools & Toolsets

Hermes ships with a broad built-in tool registry covering web search, browser automation, terminal execution, file editing, memory, delegation, RL training, messaging delivery, Home Assistant integration, and more.[10](https://blakecrosley.com/guides/hermes#fn:11) Tools are organized into logical **toolsets** that can be enabled or disabled per platform.

### High-Level Categories

| Category              | Examples                                                 | Description                                                  |
| --------------------- | -------------------------------------------------------- | ------------------------------------------------------------ |
| Web                   | `web_search`, `web_extract`                              | Search the web and extract page content                      |
| Terminal & Files      | `terminal`, `process`, `read_file`, `patch`              | Execute commands and manipulate files                        |
| Browser               | `browser_navigate`, `browser_snapshot`, `browser_vision` | Interactive browser automation with text and vision          |
| Media                 | `vision_analyze`, `image_generate`, `text_to_speech`     | Multimodal analysis and generation                           |
| Agent orchestration   | `todo`, `clarify`, `execute_code`, `delegate_task`       | Planning, clarification, code execution, subagent delegation |
| Memory & recall       | `memory`, `session_search`                               | Persistent memory + session search                           |
| Automation & delivery | `cronjob`, `send_message`                                | Scheduled tasks, outbound messaging                          |
| Integrations          | `ha_*`, MCP tools, `rl_*`                                | Home Assistant, MCP, RL training                             |

Common toolset names include `web`, `terminal`, `file`, `browser`, `vision`, `image_gen`, `moa`, `skills`, `tts`, `todo`, `memory`, `session_search`, `cronjob`, `code_execution`, `delegation`, `clarify`, `homeassistant`, and `rl`.[10](https://blakecrosley.com/guides/hermes#fn:11)

### Managing Tools

```bash
hermes chat --toolsets "web,terminal"
# Use specific toolsets
hermes tools
# Interactive per-platform tool config
hermes tools --summary
# Print enabled-tools summary
```

Tools can also be toggled mid-session via `/tools disable <name>` and `/tools enable <name>`, which resets the session so the new tool set takes effect.[9](https://blakecrosley.com/guides/hermes#fn:10)

### Terminal Backends

The terminal tool can execute commands in six different environments:[10](https://blakecrosley.com/guides/hermes#fn:11)

| Backend       | Use Case                                                    |
| ------------- | ----------------------------------------------------------- |
| `local`       | Run on your machine (default) — development, trusted tasks  |
| `docker`      | Isolated containers — security, reproducibility             |
| `ssh`         | Remote server — sandbox, keep agent away from its own code  |
| `singularity` | HPC containers — cluster computing, rootless                |
| `modal`       | Serverless cloud execution                                  |
| `daytona`     | Cloud sandbox workspace — persistent remote dev environment |

Switch backends with `hermes config set terminal.backend <name>` or in `config.yaml`:

```yaml
terminal:
  backend: docker # or: local, ssh, singularity, modal, daytona
  cwd: "." # Working directory
  timeout: 180 # Command timeout in seconds
```

**SSH backend** (recommended for security — the agent can’t modify its own code):[10](https://blakecrosley.com/guides/hermes#fn:11)

```yaml
terminal:   backend: ssh
```

```
# In ~/.hermes/.env

TERMINAL_SSH_HOST=my-server.example.com
TERMINAL_SSH_USER=myuser
TERMINAL_SSH_KEY=~/.ssh/id_rsa
```

**Docker backend:**

```yaml
terminal:
  backend: docker
  docker_image: python:3.11-slim
```

**Container resources** (applies to docker, singularity, modal, daytona):[10](https://blakecrosley.com/guides/hermes#fn:11)

```yaml
terminal:
  container_cpu: 1
  container_memory: 5120 # MB (default 5GB)
  container_disk: 51200 # MB (default 50GB)
  container_persistent: true # Persist filesystem across sessions
```

With `container_persistent: true`, installed packages, files, and config survive across sessions.[10](https://blakecrosley.com/guides/hermes#fn:11)

All container backends run with security hardening: read-only root filesystem (Docker), all Linux capabilities dropped except `DAC_OVERRIDE`, `CHOWN`, and `FOWNER`, no privilege escalation, PID limits (256 processes), full namespace isolation, persistent workspace via volumes.[10](https://blakecrosley.com/guides/hermes#fn:11)

### Background Processes

The terminal tool supports background execution with explicit process management:[10](https://blakecrosley.com/guides/hermes#fn:11)

```
terminal(command="pytest -v tests/", background=true)
# Returns: {"session_id": "proc_abc123", "pid": 12345}
process(action="list")
# Show all running processes
process(action="poll", session_id="proc_abc123")
# Check status
process(action="wait", session_id="proc_abc123")
# Block until done
process(action="log", session_id="proc_abc123")
# Full output
process(action="kill", session_id="proc_abc123")
# Terminate
process(action="write", session_id="proc_abc123", data="y")
# Send input
```

PTY mode (`pty=true`) enables interactive CLI tools like Codex and Claude Code.[10](https://blakecrosley.com/guides/hermes#fn:11)

### Sudo

If a command needs sudo, Hermes prompts for your password (cached for the session). Or set `SUDO_PASSWORD` in `~/.hermes/.env`.[10](https://blakecrosley.com/guides/hermes#fn:11)

---

## Skills System

Skills are **on-demand knowledge documents** the agent can load when needed. They follow a progressive disclosure pattern to minimize token usage and are compatible with the [agentskills.io](https://agentskills.io/) open standard.[11](https://blakecrosley.com/guides/hermes#fn:12)

**All skills live in `~/.hermes/skills/`** — the primary directory and source of truth. On fresh install, bundled skills are copied from the repo. Hub-installed and agent-created skills also go here.[11](https://blakecrosley.com/guides/hermes#fn:12)

### Progressive Disclosure

```text
Level 0: skills_list()           → [{name, description, category}, ...]   (~3k tokens)
Level 1: skill_view(name)        → Full content + metadata                 (varies)
Level 2: skill_view(name, path)  → Specific reference file                 (varies)
```

The agent only loads the full skill content when it actually needs it.[11](https://blakecrosley.com/guides/hermes#fn:12)

### SKILL.md Format

```
--- name: my-skill description: Brief description of what this skill does version: 1.3.1 platforms: [macos, linux]
# Optional — restrict to OS platforms metadata:
hermes:     tags: [python, automation]     category: devops     fallback_for_toolsets: [web]
# Conditional activation     requires_toolsets: [terminal]
# Conditional activation     config:
# Config.yaml settings       - key: my.setting         description: "What this controls"         default: "value"         prompt: "Prompt for setup" ---
# Skill Title  ## When to Use Trigger conditions for this skill.  ## Procedure 1. Step one 2. Step two  ## Pitfalls - Known failure modes and fixes  ## Verification How to confirm it worked.
```

### Conditional Activation

Skills can show or hide themselves based on which tools are available. This is most useful for **fallback skills** — free or local alternatives that should only appear when a premium tool is unavailable:[11](https://blakecrosley.com/guides/hermes#fn:12)

| Field                   | Behavior                                          |
| ----------------------- | ------------------------------------------------- |
| `fallback_for_toolsets` | Skill hidden when listed toolsets are available   |
| `fallback_for_tools`    | Same, but checks individual tools                 |
| `requires_toolsets`     | Skill hidden when listed toolsets are unavailable |
| `requires_tools`        | Same, but checks individual tools                 |

**Example:** the built-in `duckduckgo-search` skill uses `fallback_for_toolsets: [web]`. When you have `FIRECRAWL_API_KEY` set, the web toolset is available and the agent uses `web_search` — the DuckDuckGo skill stays hidden. Without the API key, the DuckDuckGo skill automatically appears as a fallback.[11](https://blakecrosley.com/guides/hermes#fn:12)

### Agent-Managed Skills

The agent can create, update, and delete its own skills via the `skill_manage` tool. This is the agent’s **procedural memory** — when it figures out a non-trivial workflow, it saves the approach as a skill for future reuse.[11](https://blakecrosley.com/guides/hermes#fn:12)

**When the agent creates skills:**[11](https://blakecrosley.com/guides/hermes#fn:12) - After completing a complex task (5+ tool calls) successfully - When it hit errors or dead ends and found the working path - When the user corrected its approach - When it discovered a non-trivial workflow

**Actions:**[11](https://blakecrosley.com/guides/hermes#fn:12)

| Action        | Use for                                           |
| ------------- | ------------------------------------------------- |
| `create`      | New skill from scratch                            |
| `patch`       | Targeted fixes (preferred — most token-efficient) |
| `edit`        | Major structural rewrites                         |
| `delete`      | Remove a skill entirely                           |
| `write_file`  | Add/update supporting files                       |
| `remove_file` | Remove a supporting file                          |

### Skill Hub

Browse, search, install, and manage skills from online registries:[6](https://blakecrosley.com/guides/hermes#fn:7)[11](https://blakecrosley.com/guides/hermes#fn:12)

```bash
hermes skills browse
# Browse all hub skills
hermes skills browse --source official
# Browse official optional skills
hermes skills search kubernetes
# Search all
sources
hermes skills search react --source skills-sh
# Search skills.sh directory
hermes skills inspect openai/skills/k8s
# Preview before installing
hermes skills install openai/skills/k8s
# Install with security scan
hermes skills install skills-sh/anthropics/skills/pdf --force
hermes skills check
# Check for upstream updates
hermes skills update
# Reinstall changed hub skills
hermes skills audit
# Re-scan installed hub skills
hermes skills uninstall k8s
hermes skills publish skills/my-skill --to github --repo owner/repo
hermes skills tap add myorg/skills-repo
# Add custom GitHub
source
```

**Integrated hub sources:**[11](https://blakecrosley.com/guides/hermes#fn:12)

| Source               | Example                                                            | Notes                                                                      |
| -------------------- | ------------------------------------------------------------------ | -------------------------------------------------------------------------- |
| `official`           | `official/security/1password`                                      | Optional skills shipped with Hermes (builtin trust)                        |
| `skills-sh`          | `skills-sh/vercel-labs/agent-skills/vercel-react-best-practices`   | Vercel’s public skills directory                                           |
| `well-known`         | `well-known:https://mintlify.com/docs/.well-known/skills/mintlify` | URL-based discovery from sites publishing `/.well-known/skills/index.json` |
| `github`             | `openai/skills/k8s`                                                | Direct GitHub repo/path installs                                           |
| `clawhub`            | —                                                                  | Third-party skills marketplace                                             |
| `claude-marketplace` | —                                                                  | Claude-compatible plugin/marketplace manifests                             |
| `lobehub`            | —                                                                  | LobeHub agent catalog conversion                                           |

**Default GitHub taps** (browsable without setup): `openai/skills`, `anthropics/skills`, `VoltAgent/awesome-agent-skills`, `garrytan/gstack`.[11](https://blakecrosley.com/guides/hermes#fn:12)

### Security Scanning

All hub-installed skills go through a security scanner that checks for data exfiltration, prompt injection, destructive commands, supply-chain signals, and other threats.[11](https://blakecrosley.com/guides/hermes#fn:12)

**Trust levels:**[11](https://blakecrosley.com/guides/hermes#fn:12)

| Level       | Source                                                    | Policy                                                                                     |
| ----------- | --------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `builtin`   | Ships with Hermes                                         | Always trusted                                                                             |
| `official`  | `optional-skills/` in the repo                            | Builtin trust, no third-party warning                                                      |
| `trusted`   | Trusted registries (`openai/skills`, `anthropics/skills`) | More permissive policy                                                                     |
| `community` | Everything else                                           | Non-dangerous findings can be overridden with `--force`; `dangerous` verdicts stay blocked |

`--force` can override non-dangerous policy blocks for community skills. It does **not** override a `dangerous` scan verdict.[11](https://blakecrosley.com/guides/hermes#fn:12)

### External Skill Directories

You can point Hermes at additional skill directories scanned alongside the local one:[11](https://blakecrosley.com/guides/hermes#fn:12)

```yaml
skills:   external_dirs:     - ~/.agents/skills     - /home/shared/team-skills     - ${SKILLS_REPO}/skills
```

Paths support `~` expansion and `${VAR}` environment variable substitution. External directories are **read-only** — when the agent creates or edits a skill, it always writes to `~/.hermes/skills/`. Local precedence wins if a skill name exists in both places.[11](https://blakecrosley.com/guides/hermes#fn:12)

---

## Persistent Memory

Hermes has bounded, curated memory that persists across sessions. Two files make up the agent’s memory, both stored in `~/.hermes/memories/`:[12](https://blakecrosley.com/guides/hermes#fn:13)

| File        | Purpose                                                                 | Char Limit                |
| ----------- | ----------------------------------------------------------------------- | ------------------------- |
| `MEMORY.md` | Agent’s personal notes — environment facts, conventions, things learned | 2,200 chars (~800 tokens) |
| `USER.md`   | User profile — preferences, communication style, expectations           | 1,375 chars (~500 tokens) |

Both are injected into the system prompt as a **frozen snapshot at session start**. The agent manages its own memory via the `memory` tool — `add`, `replace`, or `remove`.[12](https://blakecrosley.com/guides/hermes#fn:13)

**Frozen snapshot pattern:** the system prompt injection is captured once at session start and never changes mid-session. This is intentional — it preserves the LLM’s prefix cache for performance. Changes made during a session are persisted to disk immediately but don’t appear in the system prompt until the next session.[12](https://blakecrosley.com/guides/hermes#fn:13)

### What to Save

**Save these (the agent does this proactively):**[12](https://blakecrosley.com/guides/hermes#fn:13) - **User preferences:** “I prefer TypeScript over JavaScript” → `user` - **Environment facts:** “This server runs Debian 12 with PostgreSQL 16” → `memory` - **Corrections:** “Don’t use `sudo` for Docker commands, user is in docker group” → `memory` - **Conventions:** “Project uses tabs, 120-char line width, Google-style docstrings” → `memory` - **Completed work:** “Migrated database from MySQL to PostgreSQL on 2026-01-15” → `memory`

**Skip these:**[12](https://blakecrosley.com/guides/hermes#fn:13) - Trivial/obvious info - Easily re-discovered facts - Raw data dumps (too big for memory) - Session-specific ephemera - Information already in context files

### Session Search

Beyond `MEMORY.md` and `USER.md`, the agent can search its past conversations using the `session_search` tool. All CLI and messaging sessions are stored in SQLite (`~/.hermes/state.db`) with FTS5 full-text search. Queries return relevant past conversations with Gemini Flash summarization.[12](https://blakecrosley.com/guides/hermes#fn:13)

| Feature    | Persistent Memory                 | Session Search                      |
| ---------- | --------------------------------- | ----------------------------------- |
| Capacity   | ~1,300 tokens total               | Unlimited (all sessions)            |
| Speed      | Instant (in system prompt)        | Requires search + LLM summarization |
| Use case   | Key facts always available        | Finding specific past conversations |
| Management | Manually curated by agent         | Automatic — all sessions stored     |
| Token cost | Fixed per session (~1,300 tokens) | On-demand                           |

### External Memory Providers

For deeper persistent memory beyond `MEMORY.md` and `USER.md`, Hermes ships with eight external memory provider plugins: **Honcho, OpenViking, Mem0, Hindsight, Holographic, RetainDB, ByteRover, and Supermemory**.[12](https://blakecrosley.com/guides/hermes#fn:13)

External providers run **alongside** built-in memory (never replacing it) and add capabilities like knowledge graphs, semantic search, automatic fact extraction, and cross-session user modeling:[6](https://blakecrosley.com/guides/hermes#fn:7)[12](https://blakecrosley.com/guides/hermes#fn:13)

```bash
hermes memory setup
# Pick a provider and configure it
hermes memory status
# Check what's active
hermes memory off
# Disable external provider (built-in only)
```

Only one external provider can be active at a time. Built-in memory is always active.[6](https://blakecrosley.com/guides/hermes#fn:7)

---

## Personality & SOUL.md

`SOUL.md` is the **primary identity** of a Hermes instance. It occupies slot #1 in the system prompt, replacing the hardcoded default identity.[13](https://blakecrosley.com/guides/hermes#fn:14)

Hermes seeds a default `SOUL.md` automatically at `~/.hermes/SOUL.md` (or `$HERMES_HOME/SOUL.md` for custom profiles). Existing user files are never overwritten. Hermes only loads `SOUL.md` from `HERMES_HOME` — it does not look in the current working directory. This makes personality predictable across projects.[13](https://blakecrosley.com/guides/hermes#fn:14)

### What Belongs in SOUL.md

Use it for durable voice and personality guidance:[13](https://blakecrosley.com/guides/hermes#fn:14)

- tone
- communication style
- level of directness
- default interaction style
- what to avoid stylistically
- how Hermes should handle uncertainty, disagreement, ambiguity

**Use it less for:**[13](https://blakecrosley.com/guides/hermes#fn:14)

- one-off project instructions
- file paths
- repo conventions
- temporary workflow details

Those belong in `AGENTS.md`, not `SOUL.md`.

### SOUL.md vs AGENTS.md

This is the most important distinction in Hermes identity management:[13](https://blakecrosley.com/guides/hermes#fn:14)

**`SOUL.md`** — identity, tone, style, communication defaults, personality-level behavior.

**`AGENTS.md`** — project architecture, coding conventions, tool preferences, repo-specific workflows, commands, ports, paths, deployment notes.

A useful rule: if it should follow you everywhere, it belongs in `SOUL.md`. If it belongs to a project, it belongs in `AGENTS.md`.[13](https://blakecrosley.com/guides/hermes#fn:14)

### Built-in Personalities

Hermes ships with built-in personalities you can switch to with `/personality`:[13](https://blakecrosley.com/guides/hermes#fn:14)

| Name          | Description                            |
| ------------- | -------------------------------------- |
| `helpful`     | Friendly, general-purpose assistant    |
| `concise`     | Brief, to-the-point responses          |
| `technical`   | Detailed, accurate technical expert    |
| `creative`    | Innovative, outside-the-box thinking   |
| `teacher`     | Patient educator with clear examples   |
| `kawaii`      | Cute expressions, sparkles, enthusiasm |
| `catgirl`     | Neko-chan with cat-like expressions    |
| `pirate`      | Captain Hermes, tech-savvy buccaneer   |
| `shakespeare` | Bardic prose with dramatic flair       |
| `surfer`      | Chill bro vibes                        |
| `noir`        | Hard-boiled detective narration        |
| `uwu`         | Maximum cute with uwu-speak            |
| `philosopher` | Deep contemplation on every query      |
| `hype`        | MAXIMUM ENERGY                         |

**Custom personalities** in `config.yaml`:[13](https://blakecrosley.com/guides/hermes#fn:14)

```yaml
agent:   personalities:     codereviewer: >       You are a meticulous code reviewer. Identify bugs, security issues,       performance concerns, and unclear design choices. Be precise and constructive.
```

Then switch with `/personality codereviewer`.

### SOUL.md vs `/personality`

`SOUL.md` is the baseline voice. `/personality` is a session-level overlay.[13](https://blakecrosley.com/guides/hermes#fn:14) Keep a pragmatic default `SOUL.md`, then use `/personality teacher` for a tutoring conversation or `/personality creative` for brainstorming.

---

## Nous Tool Gateway (v0.10.0+)

As of Hermes Agent v0.10.0 (2026-04-16), paid **Nous Portal subscribers** gain managed access to a curated set of tools through their existing Portal credentials — no extra API keys to manage.[17](https://blakecrosley.com/guides/hermes#fn:21) The Hermes CLI itself remains MIT-licensed and fully open source. What changed is that your Portal auth now unlocks more than model inference.

### What’s in the gateway

| Tool               | Provider         | Use case                                             |
| ------------------ | ---------------- | ---------------------------------------------------- |
| Web search         | Firecrawl        | Retrieval for agents that need fresh information     |
| Image generation   | FAL / FLUX 2 Pro | Generate images inline without configuring a FAL key |
| Text-to-speech     | OpenAI TTS       | Spoken output on messaging gateways                  |
| Browser automation | Browser Use      | Headless navigation and scraping                     |

### How it works

The gateway is **opt-in per tool** via a new `use_gateway` config field. If you have Portal credentials in `hermes auth` _and_ enable the gateway for a tool, that tool’s calls route through Portal. Otherwise your direct API key (if present) is used.

```
# config.yaml — per-tool gateway opt-in tools:   web_search:     provider: firecrawl     use_gateway: true
# route via Nous Portal subscription   image_generation:     provider: fal     use_gateway: true
```

**Runtime precedence:** when the gateway is available _and_ a tool has `use_gateway: true`, Hermes prefers the gateway even if you also have a direct API key configured. This matters for billing — gateway calls draw from your Portal subscription, not from your direct API key’s balance.

### Enabling the gateway

```bash
hermes model
# select Nous Portal (OAuth flow)
hermes tools
# per-platform tool picker integrates gateway tools
hermes status
# confirms gateway/subscription detection
```

There is no separate `hermes subscribe` or `hermes login --portal` command. The subscription is detected automatically from the Portal OAuth credentials you already have in `hermes auth`.

### Pricing and access

Pricing and tier names are published on the Nous Portal pricing page (`https://portal.nousresearch.com/pricing`). This guide does not enumerate tiers because they’re the responsibility of the Portal product, not the Hermes CLI, and they change independently of Hermes releases. Sign up at `https://portal.nousresearch.com/` and check the pricing page for current tiers.

### Deprecation notice

- `HERMES_ENABLE_NOUS_MANAGED_TOOLS` env var is **removed** in v0.10.0. Managed tools are now enabled via the per-tool `use_gateway` config field and gated on your Portal subscription state.[17](https://blakecrosley.com/guides/hermes#fn:21)

### Framing: what this release is _not_

The Hermes Agent CLI is **not gated behind a subscription**. The project is still MIT-licensed, all core features (CLI, skills, memory, messaging gateway, cron, MCP, local dashboard, BYOK for every provider) work end-to-end without paying anyone. v0.10.0 adds a convenience path for users who already pay for Nous Portal — it doesn’t remove anything from the free path.

---

## Messaging Gateway

Hermes can run as a long-running gateway process that connects to **16 messaging platforms** from a single gateway process: Telegram, Discord, Slack, WhatsApp, Signal, SMS, Email, Home Assistant, Mattermost, Matrix, DingTalk, Feishu/Lark, WeCom, Weixin (WeChat), BlueBubbles (iMessage), and a generic Webhook adapter.[3](https://blakecrosley.com/guides/hermes#fn:3) v0.9.0 added iMessage via BlueBubbles (auto-webhook registration, setup wizard, crash resilience) and native WeChat support via iLink Bot API with WeCom callback mode for enterprise apps.[16](https://blakecrosley.com/guides/hermes#fn:20)

### Setup

```bash
hermes gateway setup
# Interactive platform configuration
hermes gateway install
# Install as user service (systemd/launchd)
hermes gateway start
# Start the installed service
hermes gateway stop
hermes gateway restart
hermes gateway status
hermes gateway run
# Run in foreground (debugging)
```

The interactive setup walks you through connecting each platform: API tokens, bot IDs, channel mappings, allowlists.[6](https://blakecrosley.com/guides/hermes#fn:7)

### How Messages Flow

From the upstream architecture docs:[3](https://blakecrosley.com/guides/hermes#fn:3)

```text
Platform event
→ Adapter.on_message()
→ MessageEvent
→ GatewayRunner._handle_message()
→ authorize user
→ resolve session key
→ create AIAgent with session history
→ AIAgent.run_conversation()
→ deliver response back through adapter
```

**Every messaging platform runs through the same `AIAgent` conversation loop as the CLI.** That’s why slash commands work identically in both places and why a cron job scheduled in Telegram can deliver its output to Discord — the platform difference is just at the edge.[3](https://blakecrosley.com/guides/hermes#fn:3)

### User Authorization & Pairing

```bash
hermes pairing list
# Show pending and approved users
hermes pairing approve <platform> <code>
hermes pairing revoke <platform> <user-id>
hermes pairing clear-pending
```

Pairing codes prevent random strangers from talking to your gateway. A user sends a pairing code from their messaging platform; you approve it with `hermes pairing approve`; from then on they’re authorized.[6](https://blakecrosley.com/guides/hermes#fn:7)

---

## Scheduled Tasks (Cron)

Hermes has a first-class cron system where jobs are **agent tasks**, not shell commands. Each scheduled job runs through a fresh `AIAgent` with the configured prompt, optional attached skills, and delivers results to any platform:[3](https://blakecrosley.com/guides/hermes#fn:3)[6](https://blakecrosley.com/guides/hermes#fn:7)

```bash
hermes cron list
hermes cron create --prompt "Check HN for AI news and summarize" --schedule "0 9 * * *" --deliver telegram
hermes cron edit <id>
hermes cron pause <id>
hermes cron resume <id>
hermes cron run <id>
# Trigger now on the next tick
hermes cron remove <id>
hermes cron status
# Check if scheduler is running
hermes cron tick
# Run due jobs once and exit
```

Or create one conversationally inside a messaging chat:

```
Every morning at 9am, check Hacker News for AI news and send me a summary on Telegram.
```

The agent will set up the cron job via its tools. Jobs persist in JSON and survive restarts.[3](https://blakecrosley.com/guides/hermes#fn:3)

---

## MCP Integration

Hermes supports the Model Context Protocol as both a client and a server:[6](https://blakecrosley.com/guides/hermes#fn:7)

**As a client** — connect Hermes to external MCP servers to extend its tool surface:

```bash
hermes mcp add <name> --url https://example.com/mcp
hermes mcp add <name> --command npx --args "-y,@modelcontextprotocol/server-github"
hermes mcp list
hermes mcp test <name>
hermes mcp remove <name>
hermes mcp configure <name>
# Toggle individual tool selection
```

Or manually in `config.yaml`:[14](https://blakecrosley.com/guides/hermes#fn:15)

```yaml
mcp_servers:   github:     command: npx     args: ["-y", "@modelcontextprotocol/server-github"]     env:       GITHUB_PERSONAL_ACCESS_TOKEN: "ghp_xxx"
```

**As a server** — expose Hermes conversations to other agents:

```bash
hermes mcp serve
hermes mcp serve -v
# Verbose
```

---

## Context Compression

Hermes automatically compresses long conversations to stay within your model’s context window. The compression summarizer is a separate LLM call — you can point it at any provider or endpoint.[4](https://blakecrosley.com/guides/hermes#fn:4)

```yaml
compression:   enabled: true   threshold: 0.50                           # Compress at this % of context limit   target_ratio: 0.20                        # Fraction to preserve as recent tail   protect_last_n: 20                        # Min recent messages to keep uncompressed   summary_model: "google/gemini-3-flash-preview"   summary_provider: "auto"                  # "auto", "openrouter", "nous", "codex", "main", etc.   summary_base_url: null                    # Custom OpenAI-compatible endpoint
```

**Provider options:**[4](https://blakecrosley.com/guides/hermes#fn:4)

| `summary_provider`           | `summary_base_url` | Result                                              |
| ---------------------------- | ------------------ | --------------------------------------------------- |
| `auto` (default)             | not set            | Auto-detect best available provider                 |
| `nous` / `openrouter` / etc. | not set            | Force that provider, use its auth                   |
| any                          | set                | Use the custom endpoint directly (provider ignored) |

`summary_model` must support a context length at least as large as your main model’s, since it receives the full middle section of the conversation for compression.[4](https://blakecrosley.com/guides/hermes#fn:4)

### Budget Pressure Warnings

When the agent works on a complex task with many tool calls, it can burn through its iteration budget (default: 90 turns) without realizing it. Budget pressure automatically warns the model:[4](https://blakecrosley.com/guides/hermes#fn:4)

| Threshold | Level   | What the model sees                                         |
| --------- | ------- | ----------------------------------------------------------- |
| 70%       | Caution | `[BUDGET: 63/90. 27 iterations left. Start consolidating.]` |
| 90%       | Warning | `[BUDGET WARNING: 81/90. Only 9 left. Respond NOW.]`        |

### Stream Timeouts

The LLM streaming connection has two timeout layers that auto-adjust for local providers (localhost, LAN IPs):[4](https://blakecrosley.com/guides/hermes#fn:4)

| Timeout                  | Default | Local providers      | Env var                       |
| ------------------------ | ------- | -------------------- | ----------------------------- |
| Socket read timeout      | 120s    | Auto-raised to 1800s | `HERMES_STREAM_READ_TIMEOUT`  |
| Stale stream detection   | 180s    | Auto-disabled        | `HERMES_STREAM_STALE_TIMEOUT` |
| API call (non-streaming) | 1800s   | Unchanged            | `HERMES_API_TIMEOUT`          |

The socket read timeout is raised to 30 minutes for local endpoints because local LLMs can take minutes for prefill on large contexts before producing the first token.[4](https://blakecrosley.com/guides/hermes#fn:4)

---

## Local Web Dashboard (v0.9.0+)

A browser-based dashboard for managing your Hermes Agent locally. Configure settings, monitor sessions, browse skills, and manage your gateway without touching config files or the terminal.[16](https://blakecrosley.com/guides/hermes#fn:20) Launch with `hermes dashboard`. This is the easiest onboarding path for new users who prefer a GUI.

## Background Process Monitoring (v0.9.0+)

`watch_patterns` lets you set patterns to monitor in background process output and get notified in real-time when they match.[16](https://blakecrosley.com/guides/hermes#fn:20) Monitor for errors, wait for specific events (“listening on port”), or watch build logs — all without polling. Combined with `notify_on_complete` from v0.8.0 (which notifies on background task completion), Hermes now has a full background process observability layer.[15](https://blakecrosley.com/guides/hermes#fn:19)

## Pluggable Context Engine (v0.9.0+)

Context management is now a pluggable slot via `hermes plugins`. Swap in custom context engines that control what the agent sees each turn — filtering, summarization, or domain-specific context injection.[16](https://blakecrosley.com/guides/hermes#fn:20) This decouples context strategy from the core agent loop, allowing per-project or per-domain context customization.

## Backup & Restore (v0.9.0+)

`hermes backup` creates a full archive of your config, sessions, skills, and memory. `hermes import` restores from a backup archive.[16](https://blakecrosley.com/guides/hermes#fn:20) Use this to migrate between machines, create snapshots before major changes, or share a known-good configuration with teammates.

## Termux / Android Support (v0.9.0+)

Hermes runs natively on Android via Termux. Adapted install paths, TUI optimizations for mobile screens, voice backend support, and `/image` command work on-device.[16](https://blakecrosley.com/guides/hermes#fn:20)

---

## Architecture for Practitioners

This section is for people who want to understand what’s happening under the hood so they can debug it, extend it, or reason about performance. It’s a synthesis of the upstream architecture docs.[3](https://blakecrosley.com/guides/hermes#fn:3)

### Entry Points → AIAgent

Every entry point in Hermes ultimately calls `AIAgent.run_conversation()`:

```text
┌──────────────────────────────────────────────────────────────────┐
│                        Entry Points
│ │
│ │  CLI (cli.py)    Gateway (gateway/run.py)    ACP (acp_adapter/)
│ │  Batch Runner    API Server                  Python Library
│
└──────────┬──────────────┬───────────────────────┬────────────────┘
│
│
│            ▼              ▼                       ▼
┌──────────────────────────────────────────────────────────────────┐
│                     AIAgent (run_agent.py)
│ │
│ │
┌─────────────┐
┌──────────────┐
┌──────────────┐
│ │
│ Prompt
│
│ Provider
│
│ Tool
│
│ │
│ Builder
│
│ Resolution
│
│ Dispatch
│
│ │
└──────┬──────┘
└──────┬───────┘
└──────┬───────┘
│ │
│
│
│
│ │
┌──────┴───────┐
┌──────┴───────┐
┌──────┴───────┐
│ │
│ Compression
│ │ 3 API Modes
│
│ Tool Registry│
│ │
│ & Caching
│ │ chat_compl
│
│ 47 tools
│
│ │
│
│ │ codex_resp
│
│ 20 toolsets
│
│ │
│
│ │ anthropic
│
│
│
│ │
└──────────────┘
└──────────────┘
└──────────────┘
│
└──────────────────────────────────────────────────────────────────┘
```

Diagram adapted from the upstream architecture docs.[3](https://blakecrosley.com/guides/hermes#fn:3)

**“47 tools / 20 toolsets” vs “28 tools” in your banner.** The “47 tools” count is the upstream repository’s total tool registry — every tool Hermes ships with source code for, across every toolset. Your actual running CLI will show a smaller number in its startup banner (the installation I verified this guide against reports `28 tools / 89 skills`). That’s not a bug. Many toolsets are opt-in and have to be explicitly enabled in `config.yaml` under `toolsets:` — messaging platform adapters, browser automation, heavier scraping tools, etc. The registry total is “what’s available”; the banner number is “what’s enabled in your current profile.” Check which toolsets are active with `hermes tools --list` and enable or disable individual toolsets with the `toolsets:` block in `~/.hermes/config.yaml` (or `/tools list` / `/tools enable <name>` / `/tools disable <name>` inside a running session — removing a tool triggers a session reset so the agent rebuilds its tool manifest).

### The Three API Modes

Hermes abstracts provider differences into three API modes, selected automatically at runtime:[3](https://blakecrosley.com/guides/hermes#fn:3)

| API mode             | Used by                                                                                                 |
| -------------------- | ------------------------------------------------------------------------------------------------------- |
| `chat_completions`   | OpenRouter, z.ai, Kimi, MiniMax, DeepSeek, Alibaba, most custom endpoints, any OpenAI-compatible server |
| `codex_responses`    | OpenAI Codex (via ChatGPT OAuth)                                                                        |
| `anthropic_messages` | Anthropic API (native), Anthropic OAuth, Anthropic-compatible proxies                                   |

The `runtime_provider.py` resolver maps `(provider, model)` tuples to `(api_mode, api_key, base_url)` for 18+ providers, handling OAuth flows, credential pools, and alias resolution.[3](https://blakecrosley.com/guides/hermes#fn:3)

### Data Flow Through a CLI Session

```text
User input
→ HermesCLI.process_input()
→ AIAgent.run_conversation()
→ prompt_builder.build_system_prompt()
→ runtime_provider.resolve_runtime_provider()
→ API call (chat_completions / codex_responses / anthropic_messages)
→ tool_calls?
→ model_tools.handle_function_call()
→ loop
→ final response
→ display
→ save to SessionDB
```

From the upstream architecture page.[3](https://blakecrosley.com/guides/hermes#fn:3)

### Prompt Assembly Order

The prompt stack includes:[13](https://blakecrosley.com/guides/hermes#fn:14)

1. `SOUL.md` (agent identity — or built-in fallback if unavailable)
2. Tool-aware behavior guidance
3. Memory/user context (`MEMORY.md`, `USER.md`)
4. Skills guidance
5. Context files (`AGENTS.md`, `.cursorrules`)
6. Timestamp
7. Platform-specific formatting hints
8. Optional system-prompt overlays such as `/personality`

`SOUL.md` is the foundation — everything else builds on top of it.[13](https://blakecrosley.com/guides/hermes#fn:14)

### Session Storage

SQLite-based session storage with FTS5 full-text search. Sessions have lineage tracking (parent/child across compressions), per-platform isolation, and atomic writes with contention handling.[3](https://blakecrosley.com/guides/hermes#fn:3)

### Plugin System

Three discovery sources: `~/.hermes/plugins/` (user), `.hermes/plugins/` (project), and pip entry points. Plugins register tools, hooks, and CLI commands through a context API. Memory providers are a specialized plugin type under `plugins/memory/`.[3](https://blakecrosley.com/guides/hermes#fn:3)

```bash
hermes plugins
# Interactive enable/disable UI
hermes plugins install <repo>
# Install from Git URL or owner/repo
hermes plugins enable <name>
hermes plugins disable <name>
hermes plugins list
```

### Design Principles

From the upstream architecture page:[3](https://blakecrosley.com/guides/hermes#fn:3)

| Principle                  | What it means in practice                                                                                                              |
| -------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| **Prompt stability**       | System prompt doesn’t change mid-conversation. No cache-breaking mutations except explicit user actions (`/model`)                     |
| **Observable execution**   | Every tool call is visible to the user via callbacks. Progress updates in CLI (spinner) and gateway (chat messages)                    |
| **Interruptible**          | API calls and tool execution can be cancelled mid-flight by user input or signals                                                      |
| **Platform-agnostic core** | One `AIAgent` class serves CLI, gateway, ACP, batch, and API server. Platform differences live in the entry point                      |
| **Loose coupling**         | Optional subsystems (MCP, plugins, memory providers, RL environments) use registry patterns and check_fn gating, not hard dependencies |
| **Profile isolation**      | Each profile gets its own `HERMES_HOME`, config, memory, sessions, and gateway PID. Multiple profiles run concurrently                 |

---

## Migration from OpenClaw

Hermes Agent is the successor to OpenClaw. If you’re migrating from an existing OpenClaw installation:[6](https://blakecrosley.com/guides/hermes#fn:7)[5](https://blakecrosley.com/guides/hermes#fn:5)

```bash
hermes claw migrate --dry-run
# Preview what would be migrated
hermes claw migrate --preset full
# Full migration including API keys
hermes claw migrate --preset user-data --overwrite
# User data only, no secrets
hermes claw migrate --source /custom/path
# Non-default OpenClaw location
```

`hermes claw migrate` reads from `~/.openclaw` by default (also auto-detects legacy `~/.clawdbot` and `~/.moldbot` directories) and writes to `~/.hermes`.[6](https://blakecrosley.com/guides/hermes#fn:7)

**Directly imported** (30+ categories): `SOUL.md`, `MEMORY.md`, `USER.md`, `AGENTS.md`, skills from 4 source directories, default model, custom providers, MCP servers, messaging platform tokens and allowlists (Telegram, Discord, Slack, WhatsApp, Signal, Matrix, Mattermost), agent defaults (reasoning effort, compression, human delay, timezone, sandbox), session reset policies, approval rules, TTS config, browser settings, tool settings, exec timeout, command allowlist, gateway config, and API keys from 3 sources.[6](https://blakecrosley.com/guides/hermes#fn:7)

**Archived for manual review:** cron jobs, plugins, hooks/webhooks, memory backend (QMD), skills registry config, UI/identity, logging, multi-agent setup, channel bindings, `IDENTITY.md`, `TOOLS.md`, `HEARTBEAT.md`, `BOOTSTRAP.md`.[6](https://blakecrosley.com/guides/hermes#fn:7)

API key resolution checks three sources in priority order: config values → `~/.openclaw/.env` → `auth-profiles.json`.[6](https://blakecrosley.com/guides/hermes#fn:7)

---

## Troubleshooting

### “API key not set”

Run `hermes model` to configure your provider interactively, or `hermes config set OPENROUTER_API_KEY your_key`. The `hermes doctor` command will tell you exactly which keys are missing.[7](https://blakecrosley.com/guides/hermes#fn:8)

### “Context limit: 2048 tokens” at startup (local models)

Hermes auto-detects context length from your server’s `/v1/models` endpoint, but many local servers report low defaults. Set it explicitly in `config.yaml`:[2](https://blakecrosley.com/guides/hermes#fn:2)

```yaml
model:   default: your-model   provider: custom   base_url: http://localhost:11434/v1   context_length: 32768
```

### Tool calls appear as text instead of executing

Your server doesn’t have tool calling enabled, or the model doesn’t support it through the server’s implementation.[2](https://blakecrosley.com/guides/hermes#fn:2)

| Server    | Fix                                                                                          |
| --------- | -------------------------------------------------------------------------------------------- |
| llama.cpp | Add `--jinja` to the startup command                                                         |
| vLLM      | Add `--enable-auto-tool-choice --tool-call-parser hermes`                                    |
| SGLang    | Add `--tool-call-parser qwen` (or appropriate parser)                                        |
| Ollama    | Tool calling is enabled by default — check your model supports it with `ollama show <model>` |
| LM Studio | Update to 0.3.6+ and use a model with native tool support                                    |

### Responses get cut off mid-sentence

Two possible causes:[2](https://blakecrosley.com/guides/hermes#fn:2)

1. **Low output cap** (`max_tokens`) on the server — SGLang defaults to 128 tokens per response. Set `--default-max-tokens` on the server or configure `model.max_tokens` in `config.yaml`.
2. **Context exhaustion** — The model filled its context window. Increase `model.context_length` or enable context compression in Hermes.

### “Connection refused” from WSL2 to a Windows-hosted model server

WSL2 uses a virtual network adapter with its own subnet — `localhost` inside WSL2 refers to the Linux VM, not the Windows host. Two options:[2](https://blakecrosley.com/guides/hermes#fn:2)

**Mirrored networking** (Windows 11 22H2+): edit `%USERPROFILE%\.wslconfig`:

```
[wsl2] networkingMode=mirrored
```

Then `wsl --shutdown` and restart. `localhost` now works bidirectionally.

**Host IP fallback** (older Windows): get the Windows host IP from inside WSL2 and use it instead of `localhost`:

```bash
ip route show | grep -i default | awk '{ print $3 }'
# Use that IP as the base_url host
```

You also need the model server to bind to `0.0.0.0`, not `127.0.0.1` — set `OLLAMA_HOST=0.0.0.0` for Ollama, add `--host 0.0.0.0` for llama-server/SGLang, or enable “Serve on Network” in LM Studio.[2](https://blakecrosley.com/guides/hermes#fn:2)

### Where is everything?

`hermes status` and `hermes dump` are your friends here. `hermes logs list` shows all log files with sizes. `hermes config path` prints the config file location. `hermes config env-path` prints the `.env` location.[6](https://blakecrosley.com/guides/hermes#fn:7)

---

## FAQ

### What’s the difference between Hermes Agent and Claude Code?

Claude Code is Anthropic’s official CLI, locked to Anthropic models. Hermes Agent is an open-source agent framework from Nous Research that works with any OpenAI-compatible provider — Nous Portal, OpenRouter, Anthropic, GitHub Copilot, z.ai, Kimi, MiniMax, DeepSeek, Hugging Face, Google, or your own self-hosted endpoint.[1](https://blakecrosley.com/guides/hermes#fn:1)[2](https://blakecrosley.com/guides/hermes#fn:2) Hermes also ships a messaging gateway for Telegram/Discord/Slack/WhatsApp/Signal that Claude Code does not have.

### Can I use Hermes with an Anthropic API key?

Yes. Three ways:[2](https://blakecrosley.com/guides/hermes#fn:2)

1. Set `ANTHROPIC_API_KEY` in `~/.hermes/.env` and run `hermes chat --provider anthropic --model claude-sonnet-4-6`
2. Run `hermes model` and select Anthropic — Hermes will use Claude Code’s credential store when available
3. Set a manual `ANTHROPIC_TOKEN` (setup-token or OAuth token) as a fallback

Option 2 is preferred if you already use Claude Code on the same machine — it keeps refreshable Claude credentials refreshable.

### How do I switch providers without losing my conversation?

Use `/model provider:model` inside a session. The conversation history, memory, and skills all carry over:[9](https://blakecrosley.com/guides/hermes#fn:10)

```bash
/model zai:glm-5
/model openrouter:anthropic/claude-sonnet-4
/model custom:local:qwen-2.5
```

### I configured Anthropic but vision/web/compression don’t work

You’re hitting the auxiliary model fallback. Vision, web summarization, compression, and other side tasks use a separate auxiliary LLM — by default Gemini Flash via auto-detection (OpenRouter → Nous → Codex). If none of those are configured and you only have Anthropic set up, these features degrade silently.[4](https://blakecrosley.com/guides/hermes#fn:4)

Fix: either add an `OPENROUTER_API_KEY` for auxiliary tasks, or reconfigure auxiliary slots to use your main provider. Note that context compression lives in its own top-level `compression:` block and takes `summary_provider`, not `auxiliary.compression.provider` — the `auxiliary.compression` slot only exposes a `timeout`. Full fix:

```yaml
auxiliary:   vision:      { provider: "main" }   web_extract: { provider: "main" }  compression:   summary_provider: "main"
```

### What is the difference between SOUL.md and AGENTS.md?

`SOUL.md` is your agent’s identity — tone, style, communication defaults. It lives in `~/.hermes/SOUL.md` and follows you everywhere. `AGENTS.md` is project-specific — architecture, conventions, commands, paths — and lives in your project directory.[13](https://blakecrosley.com/guides/hermes#fn:14) If it should follow you everywhere, `SOUL.md`. If it belongs to a project, `AGENTS.md`.

### How do I run multiple Hermes instances side-by-side?

Profiles. Each profile gets its own `HERMES_HOME`, config, memory, sessions, and gateway PID:[6](https://blakecrosley.com/guides/hermes#fn:7)

```bash
hermes profile create work --clone
hermes profile use work
# Sticky default
hermes -p work chat -q "..."
# One-off without switching
hermes profile alias work --name h-work
# Wrapper script
```

### Does Hermes support local LLMs?

Yes, through the custom endpoint path. Hermes works with any OpenAI-compatible server: Ollama, vLLM, SGLang, llama.cpp/llama-server, LM Studio, LocalAI, Jan, or your own.[2](https://blakecrosley.com/guides/hermes#fn:2) See [Custom & Self-Hosted Endpoints](https://blakecrosley.com/guides/hermes#custom-self-hosted-endpoints) for per-server setup.

### Why does my startup banner show fewer tools than the guide says Hermes has?

The guide cites 47 tools / 20 toolsets from the upstream architecture registry — that’s the full count of tools Hermes ships source code for across every toolset. Your running install shows a smaller number in the banner (the reference install used for this guide reports 28 tools) because Hermes only enables the default toolset set at startup. Many toolsets are opt-in: messaging gateway adapters, browser automation, heavier scraping stacks, and several specialized integrations have to be explicitly listed under `toolsets:` in `~/.hermes/config.yaml` before they load. Registry total = “what’s available if you enable it.” Banner total = “what your current profile actually loaded.” Use `hermes tools --list` to see which toolsets are active and which are available but disabled. Toggle individual toolsets at runtime with `/tools enable <name>` and `/tools disable <name>` (disabling triggers a session reset so the agent rebuilds its tool manifest with the new shape).

### How does Hermes handle model fallback when my primary provider fails?

Configure a `fallback_model` block in `config.yaml`:[2](https://blakecrosley.com/guides/hermes#fn:2)

```yaml
fallback_model:   provider: openrouter   model: anthropic/claude-sonnet-4
```

When the primary fails (rate limit, server error, auth failure), Hermes swaps to the fallback mid-session without losing conversation history. Fires at most once per session.

### Can the agent improve its own skills over time?

Yes — that’s the “self-improving” part of Hermes Agent. The agent can create, update, and delete skills via the `skill_manage` tool. When it figures out a non-trivial workflow, it saves the approach as a skill for future reuse.[11](https://blakecrosley.com/guides/hermes#fn:12) The agent creates skills after complex tasks (5+ tool calls), when it hits errors and finds the working path, when you correct its approach, or when it discovers a non-trivial workflow.

### Is there an IDE integration?

Yes — Hermes can run as an ACP (Agent Client Protocol) server for VS Code, Zed, and JetBrains:[6](https://blakecrosley.com/guides/hermes#fn:7)

```bash
pip install -e '.[acp]'
hermes acp
```

---

## Changelog

| Date       | Change                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | Source                                                                                                |
| ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| 2026-04-16 | Guide v1.2: Added v0.10.0 — **Nous Tool Gateway**. Paid Nous Portal subscribers now access managed tools (Firecrawl web search, FAL / FLUX 2 Pro image generation, OpenAI TTS, Browser Use browser automation) with no extra API keys. Opt-in per tool via new `use_gateway` config field. Runtime prefers gateway over direct API keys when both are configured. `HERMES_ENABLE_NOUS_MANAGED_TOOLS` env var removed. Hermes Agent CLI remains MIT-licensed and fully free. | [17](https://blakecrosley.com/guides/hermes#fn:21)                                                    |
| 2026-04-13 | Guide v1.1: Added v0.8.0 and v0.9.0 features. Local web dashboard, `/fast` mode, iMessage + WeChat platforms (16 total), background process monitoring (`watch_patterns`), pluggable context engine, `hermes backup`/`hermes import`, Termux/Android, xAI + MiMo + Google AI Studio + Qwen providers, `/debug` command, comprehensive security hardening.                                                                                                                   | [15](https://blakecrosley.com/guides/hermes#fn:19) [16](https://blakecrosley.com/guides/hermes#fn:20) |
| 2026-04-10 | Guide v1.0: Initial release covering Hermes Agent v0.7.0. Provider auth, config, CLI, slash commands, tools, skills, memory, gateway, cron, MCP, compression, architecture, OpenClaw migration, troubleshooting, FAQ.                                                                                                                                                                                                                                                       |                                                                                                       |

---

←prevScheduled Tasks (Cron)nextContext Compression→

$ echo "Maintained by Blake Crosley"

Maintained by [Blake Crosley](https://blakecrosley.com/) | Last updated 2026-04-16

NORMALhermes.mdEOF

[Blake Crosley](https://blakecrosley.com/)

Designer, developer, and maker of things.

### Navigate

[About](https://blakecrosley.com/about)[Work](https://blakecrosley.com/#work)[Writing](https://blakecrosley.com/writing)[Guides](https://blakecrosley.com/guides)[Contact](https://blakecrosley.com/#contact)

### Guides

[Claude Code](https://blakecrosley.com/guides/claude-code)[Midjourney](https://blakecrosley.com/guides/midjourney)[Design Principles](https://blakecrosley.com/guides/design)[Obsidian](https://blakecrosley.com/guides/obsidian)[Suno](https://blakecrosley.com/guides/suno)

### Projects

[941 Apps](https://941apps.com/)[Ace Citizenship](https://acecitizenship.app/)[ResumeGeni](https://resumegeni.com/)[941 Return](https://941return.com/)[Banana List](https://941getbananas.com/)[Tappy Color](https://blakecrosley.com/work/tappy-color)[h3arted](https://h3arted.com/)[Dream of Electric](https://dreamofelectric.com/)

### Connect

[blake@941apps.com](mailto:blake@941apps.com)[LinkedIn](https://www.linkedin.com/in/blakecrosley/)[Instagram](https://www.instagram.com/dream_of_electric/)

© 2026 Blake Crosley. All rights reserved.

Pasadena, California
