# Claude Code statusline

**🇬🇧 English** · [🇨🇿 Čeština](README.cs.md)

A two-line **status line for [Claude Code](https://claude.com/claude-code)** that tells you
not just how much limit you've used, but **when you'll run out** at your current pace, and
how long until the prompt cache expires. Plus model, folder, detailed git status and
context usage. For anyone who runs long sessions on a subscription and wants to see the
wall coming before they hit it.

Author: Martin Žatkovič, built on [faborsky/claude-code-statusline](https://github.com/faborsky/claude-code-statusline).

```
«🏢 WORK» [Opus 5.5[1m] Med] | 📁 my-project | 🌿 main ↑2 +1~3?1 | Context: ███░░░░░░░ 38% (152k/400k)
Limits: 5h:60%⟳11:25 ⚠10:35 · 7d:20%⟳05.11 →59% | cache 42m (⌛09:54/1h) | ⛵◐
```

## What it shows

**Line 1: where you are**

| Part | Meaning |
|---|---|
| `«🏢 WORK»` | **instance badge**: which Claude Code profile the session runs in, when you use several ([see below](#instance-badge)). Hidden for the default `~/.claude` |
| `[Opus 5.5[1m] Med]` | model, `[1m]` = 1M context window, reasoning effort (`Low` / `Med` / `High` / `XHigh` / `Max`) |
| `📁 my-project` | current folder |
| `🌿 main ↑2 ↓1 +1~3?1⚑1` | git branch, commits ahead/behind upstream, `+` staged, `~` modified, `?` untracked, `⚑` stash entries; `no-git` outside a repo |
| `Context: ███░░ 38% (152k/400k)` | tokens in context against a **400k budget**, not against the model's full window ([why](#why-400k)) |

**Line 2: how long you can keep going**

| Part | Meaning |
|---|---|
| `5h:60%⟳11:25` | five-hour limit usage and the clock time it resets |
| `⚠10:35` | **red:** at your current pace you hit 100 % at 10:35, *before* the reset |
| `→59%` | **grey:** at your current pace you'll be at 59 % when the window resets, so you're fine |
| `7d:20%⟳05.11` | the same for the weekly cap, reset shown as a date |
| `cache 42m (⌛09:54/1h)` | **prompt cache**: minutes until it expires, the clock time, and which TTL you paid for (`5m` or `1h`). `cache ✗` = expired, the next message pays for a full re-read |
| `⛵ name◐` | Orca worktree and its card status (`○` todo, `◐` in progress, `◔` in review, `●` done); only when the `orca` CLI is installed |

Colors for context and limit usage:

- 🟢 green < 50%
- 🟡 yellow ≥ 50%
- 🟠 orange ≥ 70%
- 🔴 red ≥ 90%

The cache countdown turns yellow under 15 minutes and orange under 5.

Every segment on line 2 hides itself when there's nothing to show: limits only appear on a
Pro/Max/Team subscription after the first response in a session, cache only once there's a
transcript, Orca only with its CLI. If line 2 is empty, you get a single line.

## Requirements

- **macOS**: the script uses BSD `date -r` and `stat -f`. Linux and Windows aren't supported yet
- **[`jq`](https://jqlang.github.io/jq/)**: parses the JSON Claude Code sends on stdin (`brew install jq`)
- **python3**: for the cache segment (ships with the Xcode command line tools)
- **git**: optional; outside a repository it shows `no-git`

> The status line runs often, so nothing in it waits on the network: git is one
> `git status --porcelain=v2` call with no fetch, `cache-expiry.py` reads only the last
> 512 kB of the transcript, and the `orca` CLI is called in the background with its result
> cached for 20 seconds.

## Installation

1. Clone the repo, for example into your Claude config dir:

   ```bash
   git clone https://github.com/zatkoma/claude-code-statusline.git ~/.claude/claude-code-statusline
   ```

   The script finds `lib/cache-expiry.py` next to itself, so any location works.

2. Enable it in `~/.claude/settings.json`:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/claude-code-statusline/statusline.sh",
       "refreshInterval": 10
     }
   }
   ```

   `refreshInterval` (seconds) matters here: without it the status line only redraws on
   activity, so the cache countdown and the predictions freeze while you're idle.

3. Open a new session and the status line appears at the bottom.

To update: `git -C ~/.claude/claude-code-statusline pull`.

## Instance badge

If you run several Claude Code profiles via `CLAUDE_CONFIG_DIR` (say work and personal),
the badge shows which one a session belongs to:

| Config dir | Badge |
|---|---|
| `~/.claude` (default) | none |
| `~/.claude-work` | `«🏢 WORK»` blue |
| `~/.claude-personal` | `«🏠 PERSONAL»` green |
| anything else, e.g. `~/.claude-lab` | `«⚙ claude-lab»` magenta |

Custom name and color via `env` in that profile's `settings.json`:

```json
{
  "env": {
    "CLAUDE_INSTANCE": "🧪 LAB",
    "CLAUDE_INSTANCE_COLOR": "\u001b[35m"
  }
}
```

## Customization

Environment variables:

| Variable | Default | What it does |
|---|---|---|
| `CLAUDE_CTX_BUDGET` | `400000` | context budget the percentage is measured against |
| `CLAUDE_CACHE_TTL_MIN` | — | force the cache TTL in minutes instead of reading it from the transcript |
| `CLAUDE_INSTANCE` | from config dir | badge text |
| `CLAUDE_INSTANCE_COLOR` | from config dir | badge ANSI color |

In the script:

- **Color thresholds**: the `50 / 70 / 90` values in `pct_color`.
- **Badge mapping**: the `case "$CFG"` block in the *Instance badge* section.
- **Prediction warm-up**: the `900` seconds in `predict_full`, during which predictions stay silent.
- **Orca refresh**: `ORCA_TTL` in the *Orca worktree* section.
- **Layout and order**: the *Assemble* section at the end of the file.

## How it's calculated

**Context.** Tokens of the last request, `input + cache_creation + cache_read` from
`context_window.current_usage`, with `used_percentage × window size` as a fallback. The
whole payload is parsed in **one** `jq` pass.

<a id="why-400k"></a>**Why 400k.** With a 1M window the percentage would sit near zero for
most of a session and tell you nothing. 400k is a chosen point at which it's worth starting
a fresh session. Above it the bar goes past 100 %. Change it with `CLAUDE_CTX_BUDGET`.

**Predictions.** Linear from your pace so far in the window: window start = reset time −
window length (5 h or 7 days). If 100 % arrives before the reset, you get a red `⚠time`;
otherwise a grey `→N%` for where you'll land at the reset. The first 15 minutes of a window
stay silent, the estimate would just be noise.

**Cache.** `lib/cache-expiry.py` reads `usage.cache_creation` from the session transcript,
which is what the API actually billed. A non-zero `ephemeral_1h_input_tokens` means a
1-hour cache write, `ephemeral_5m_input_tokens` a 5-minute one. Expiry is counted from the
timestamp of the last request, since every cache read extends the window. Nothing is guessed.

## Credit

Built on **Jindřich Fáborský**'s [claude-code-statusline](https://github.com/faborsky/claude-code-statusline)
(MIT), which itself started from **Leonardo Grigorio**'s tutorial *"My actual Claude Code
workflow"*. On top of that this version adds the instance badge, the two-line layout, limit
predictions, the cache countdown, detailed git status, the 400k context budget and the
Orca segment.

## License

[MIT](LICENSE) © 2026 Jindřich Fáborský, Martin Žatkovič.
