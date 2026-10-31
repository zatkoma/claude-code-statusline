# Changelog

## 2026-10-31: dynamic 5h prediction

- The 5-hour limit prediction uses your **pace over the last 30 minutes** instead of the
  average of the whole window, so it reacts as soon as you speed up or slow down.
- New `↗` / `↘` arrow after the 5h prediction: faster / slower than the window average.
- The weekly prediction stays on the whole-window average on purpose: a short window would
  carry the day/night rhythm.
- The status line now keeps a small limit history in `$TMPDIR`, shared by all sessions of one
  config dir. Falls back to the window average when there's too little history or it can't
  be written.

## 2026-10-31: two lines

- Two-line layout: where you are on line 1, how long you can keep going on line 2.
- Limit predictions: red `⚠time` when you'll hit 100 % before the reset, grey `→N%` otherwise.
- Prompt cache countdown read from the billed usage in the transcript (`lib/cache-expiry.py`).
- Context measured against a 400k budget with the token count (`CLAUDE_CTX_BUDGET`).
- Detailed git status: ahead/behind, staged, modified, untracked, stash.
- Orca worktree segment when the `orca` CLI is installed.
- No badge for the default `~/.claude`.
- English README, Czech in `README.cs.md`; MIT license.

## 2026-07-25: first version

- Fork of [faborsky/claude-code-statusline](https://github.com/faborsky/claude-code-statusline)
  with an instance badge per config dir and limit reset times.
