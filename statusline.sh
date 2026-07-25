#!/bin/bash
# Claude Code status line — instance badge, model, folder, git branch, context bar, rate limits.
#
# Based on faborsky/claude-code-statusline (https://github.com/faborsky/claude-code-statusline),
# itself adapted from Leonardo Grigorio's tutorial "My actual Claude Code workflow".
# Local modification: leading INSTANCE badge so you can tell which Claude config
# dir (work / personal / …) a session belongs to when several run at once.
#
# Instance detection, in priority order:
#   1. $CLAUDE_INSTANCE / $CLAUDE_INSTANCE_COLOR  — set via settings.json "env" (explicit)
#   2. basename of $CLAUDE_CONFIG_DIR             — .claude-work -> WORK, .claude -> PERSONAL
#
# Install: point settings.json -> statusLine at this file, then chmod +x.
# Requires: jq, git (git optional — falls back to "no-git").

input=$(cat)

# One jq pass: model, effort, context %, rate limits.
IFS=$'\x1f' read -r MODEL EFFORT PERCENT RL5 RL7 RL5R RL7R <<EOF
$(printf '%s' "$input" | jq -r '
  [ (.model.display_name // "?"),
    (.effort.level // ""),
    ((.context_window.used_percentage
        // (if (.context_window.context_window_size // 0) > 0
            then (.context_window.total_input_tokens // 0) * 100 / .context_window.context_window_size
            else 0 end)) | floor),
    ((.rate_limits.five_hour.used_percentage // -1) | floor),
    ((.rate_limits.seven_day.used_percentage // -1) | floor),
    ((.rate_limits.five_hour.resets_at // -1) | floor),
    ((.rate_limits.seven_day.resets_at // -1) | floor)
  ] | map(tostring) | join("")' 2>/dev/null)
EOF

# Defaults — guard against jq being absent or failing.
[ -z "$PERCENT" ] && PERCENT=0
[ -z "$MODEL" ]   && MODEL="?"
[ -z "$RL5" ]     && RL5=-1
[ -z "$RL7" ]     && RL7=-1
[ -z "$RL5R" ]    && RL5R=-1
[ -z "$RL7R" ]    && RL7R=-1

# Colors.
C_RESET=$'\033[0m'; C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'
C_YELLOW=$'\033[33m'; C_ORANGE=$'\033[38;5;208m'; C_RED=$'\033[31m'
C_BLUE=$'\033[38;5;39m'; C_MAGENTA=$'\033[35m'
C_LABEL=$'\033[90m'   # dim grey for miniature labels

# --- Instance badge -------------------------------------------------------
# 1) explicit override from settings.json "env"
INSTANCE="$CLAUDE_INSTANCE"
INSTANCE_COLOR="$CLAUDE_INSTANCE_COLOR"
# 2) derive from the active config dir
if [ -z "$INSTANCE" ]; then
  CFG=$(basename "${CLAUDE_CONFIG_DIR:-$HOME/.claude}")
  case "$CFG" in
    .claude-work) INSTANCE="🏢 WORK";     INSTANCE_COLOR="$C_BLUE" ;;
    .claude)      INSTANCE="🏠 PERSONAL"; INSTANCE_COLOR="$C_GREEN" ;;
    *)            INSTANCE="⚙ ${CFG#.}";  INSTANCE_COLOR="$C_MAGENTA" ;;
  esac
fi
[ -z "$INSTANCE_COLOR" ] && INSTANCE_COLOR="$C_MAGENTA"
# --------------------------------------------------------------------------

# Model label + effort (·xhigh); effort hides itself when absent.
if [ -n "$EFFORT" ]; then MODEL_LABEL="${MODEL} ·${EFFORT}"; else MODEL_LABEL="$MODEL"; fi

# Git branch + dirty flag.
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -n "$BRANCH" ]; then
  [ -n "$(git status --porcelain 2>/dev/null)" ] && GIT="${BRANCH}±" || GIT="${BRANCH}"
else
  GIT="no-git"
fi
DIR=$(basename "$(pwd)")

# Shared color thresholds (context % and rate limits).
pct_color() {
  if   [ "$1" -ge 90 ]; then printf '%s' "$C_RED"
  elif [ "$1" -ge 70 ]; then printf '%s' "$C_ORANGE"
  elif [ "$1" -ge 50 ]; then printf '%s' "$C_YELLOW"
  else                       printf '%s' "$C_GREEN"; fi
}
PC=$(pct_color "$PERCENT")

# 10-segment progress bar.
FILLED=$((PERCENT / 10)); [ "$FILLED" -gt 10 ] && FILLED=10
BAR=""
for ((i = 1; i <= 10; i++)); do
  if [ "$i" -le "$FILLED" ]; then BAR="${BAR}█"; else BAR="${BAR}░"; fi
done

# Format a Unix-epoch reset time; empty when the field is absent (-1) or unparsable.
# $1 = epoch, $2 = date format (e.g. %H:%M for 5h, %d.%m for 7d).
fmt_reset() {
  [ "$1" -ge 0 ] 2>/dev/null || return 0
  date -r "$1" +"$2" 2>/dev/null
}

# Rate-limit value — empty when both fields are missing (segment hides itself).
# Shows used % and, when available, when the window resets: 5h:12% ⟳14:30
RL=""
if [ "$RL5" -ge 0 ]; then
  RL="$(pct_color "$RL5")5h:${RL5}%${C_RESET}"
  R=$(fmt_reset "$RL5R" "%H:%M"); [ -n "$R" ] && RL="${RL}${C_LABEL}⟳${R}${C_RESET}"
fi
if [ "$RL7" -ge 0 ]; then
  [ -n "$RL" ] && RL="${RL} · "
  RL="${RL}$(pct_color "$RL7")7d:${RL7}%${C_RESET}"
  R=$(fmt_reset "$RL7R" "%d.%m"); [ -n "$R" ] && RL="${RL}${C_LABEL}⟳${R}${C_RESET}"
fi

# Assemble: «INSTANCE» [model ·effort] | 📁 dir | 🌿 branch | Context: <bar> % | Limits: 5h/7d
printf "%s«%s»%s %s[%s]%s | 📁 %s | 🌿 %s | %sContext:%s %s%s%s %s%d%%%s" \
  "$INSTANCE_COLOR" "$INSTANCE" "$C_RESET" \
  "$C_CYAN" "$MODEL_LABEL" "$C_RESET" "$DIR" "$GIT" \
  "$C_LABEL" "$C_RESET" "$PC" "$BAR" "$C_RESET" "$PC" "$PERCENT" "$C_RESET"
[ -n "$RL" ] && printf " | %sLimits:%s %s" "$C_LABEL" "$C_RESET" "$RL"
exit 0
