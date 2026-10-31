#!/bin/bash
# Claude Code status line — instance badge, model, folder, git branch, context bar, rate limits.
# Řádek 1 končí kontextem (% vůči 400k), limity/cache/orca jsou na řádku 2.
#
# Based on faborsky/claude-code-statusline (https://github.com/faborsky/claude-code-statusline),
# itself adapted from Leonardo Grigorio's tutorial "My actual Claude Code workflow".
# https://github.com/zatkoma/claude-code-statusline — popis a instalace v README.
#
# Badge instance, podle priority:
#   1. $CLAUDE_INSTANCE / $CLAUDE_INSTANCE_COLOR  — z settings.json "env" (explicitně)
#   2. název $CLAUDE_CONFIG_DIR                   — .claude-work -> WORK, .claude-personal -> PERSONAL
#   Výchozí ~/.claude badge nemá.
#
# Požaduje: jq, python3 (cache), git (volitelně). Psáno pro macOS.

input=$(cat)

# One jq pass: model, effort, context %, rate limits.
IFS=$'\x1f' read -r MODEL EFFORT TOKENS RL5 RL7 RL5R RL7R <<EOF
$(printf '%s' "$input" | jq -r '
  [ (.model.display_name // "?"),
    (.effort.level // ""),
    # Tokeny v kontextu: poslední request (input + cache), záložně z used_percentage.
    ((.context_window.current_usage
        | if . then (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)
          else null end)
      // ((.context_window.used_percentage // 0) * (.context_window.context_window_size // 0) / 100)
      | floor),
    ((.rate_limits.five_hour.used_percentage // -1) | floor),
    ((.rate_limits.seven_day.used_percentage // -1) | floor),
    ((.rate_limits.five_hour.resets_at // -1) | floor),
    ((.rate_limits.seven_day.resets_at // -1) | floor)
  ] | map(tostring) | join("")' 2>/dev/null)
EOF

# Defaults — guard against jq being absent or failing.
[ -z "$TOKENS" ]  && TOKENS=0
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
    .claude-work)     INSTANCE="🏢 WORK";     INSTANCE_COLOR="$C_BLUE" ;;
    .claude-personal) INSTANCE="🏠 PERSONAL"; INSTANCE_COLOR="$C_GREEN" ;;
    .claude)          INSTANCE="" ;;
    *)                INSTANCE="⚙ ${CFG#.}";  INSTANCE_COLOR="$C_MAGENTA" ;;
  esac
fi
[ -z "$INSTANCE_COLOR" ] && INSTANCE_COLOR="$C_MAGENTA"
BADGE=""; [ -n "$INSTANCE" ] && BADGE="${INSTANCE_COLOR}«${INSTANCE}»${C_RESET} "
# --------------------------------------------------------------------------

# Model label + effort: „Opus 5.5 (1M context)" + medium → „Opus 5.5[1m] Med".
case "$MODEL" in
  *"(1M context)"*) MODEL="${MODEL% (1M context)}"; case "$MODEL" in *"[1m]") ;; *) MODEL="${MODEL}[1m]" ;; esac ;;
esac
case "$EFFORT" in
  low) EFFORT="Low" ;; medium) EFFORT="Med" ;; high) EFFORT="High" ;;
  xhigh) EFFORT="XHigh" ;; max) EFFORT="Max" ;;
esac
if [ -n "$EFFORT" ]; then MODEL_LABEL="${MODEL} ${EFFORT}"; else MODEL_LABEL="$MODEL"; fi

# Git: branch, ↑ahead ↓behind vůči upstreamu, +staged ~změněné ?nové, ⚑stash.
# Jedno volání `git status --porcelain=v2 --branch`, žádné fetchování.
GIT_STATUS=$(git status --porcelain=v2 --branch 2>/dev/null)
if [ -n "$GIT_STATUS" ]; then
  read -r BRANCH G_AHEAD G_BEHIND G_STAGED G_MOD G_NEW <<<"$(printf '%s\n' "$GIT_STATUS" | awk '
    /^# branch.head /{h=$3}
    /^# branch.ab /{a=substr($3,2); b=substr($4,2)}
    /^[12u] /{x=substr($2,1,1); y=substr($2,2,1); if (x!=".") s++; if (y!=".") m++}
    /^\? /{n++}
    END{print h, a+0, b+0, s+0, m+0, n+0}')"
  G_STASH=$(git rev-list --walk-reflogs --count refs/stash 2>/dev/null || echo 0)
  GIT="$BRANCH"
  [ "$G_AHEAD" -gt 0 ]  && GIT="${GIT} ${C_GREEN}↑${G_AHEAD}${C_RESET}"
  [ "$G_BEHIND" -gt 0 ] && GIT="${GIT} ${C_RED}↓${G_BEHIND}${C_RESET}"
  G_DIRTY=""
  [ "$G_STAGED" -gt 0 ] && G_DIRTY="${G_DIRTY}${C_GREEN}+${G_STAGED}${C_RESET}"
  [ "$G_MOD" -gt 0 ]    && G_DIRTY="${G_DIRTY}${C_YELLOW}~${G_MOD}${C_RESET}"
  [ "$G_NEW" -gt 0 ]    && G_DIRTY="${G_DIRTY}${C_LABEL}?${G_NEW}${C_RESET}"
  [ "$G_STASH" -gt 0 ]  && G_DIRTY="${G_DIRTY}${C_MAGENTA}⚑${G_STASH}${C_RESET}"
  [ -n "$G_DIRTY" ] && GIT="${GIT} ${G_DIRTY}"
else
  BRANCH=""; GIT="no-git"
fi
DIR=$(basename "$(pwd)")

# Shared color thresholds (context % and rate limits).
pct_color() {
  if   [ "$1" -ge 90 ]; then printf '%s' "$C_RED"
  elif [ "$1" -ge 70 ]; then printf '%s' "$C_ORANGE"
  elif [ "$1" -ge 50 ]; then printf '%s' "$C_YELLOW"
  else                       printf '%s' "$C_GREEN"; fi
}
# Context % se počítá vůči 400k, ne vůči oknu modelu (1M) — nad 400k jde přes 100 %.
CTX_BUDGET=${CLAUDE_CTX_BUDGET:-400000}
PERCENT=$(( TOKENS * 100 / CTX_BUDGET ))
TOKENS_K=$(( (TOKENS + 500) / 1000 ))
PC=$(pct_color "$PERCENT")

# 10-segment progress bar.
FILLED=$((PERCENT / 10)); [ "$FILLED" -gt 10 ] && FILLED=10
BAR=""
for ((i = 1; i <= 10; i++)); do
  if [ "$i" -le "$FILLED" ]; then BAR="${BAR}█"; else BAR="${BAR}░"; fi
done

# --- Cache TTL ------------------------------------------------------------
# Kdy vyprší prompt cache konverzace. Skutečné TTL i kotvu (čas posledního
# requestu) řeší lib/cache-expiry.py vedle tohohle skriptu — čte to z účtovaného
# `usage.cache_creation` v transcriptu, nehádá se. Ruční přebití:
# CLAUDE_CACHE_TTL_MIN.
CACHE=""
TRANSCRIPT=$(printf '%s' "$input" | jq -r '.transcript_path // ""' 2>/dev/null)
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  CACHE_PY="$(dirname "${BASH_SOURCE[0]}")/lib/cache-expiry.py"
  [ -f "$CACHE_PY" ] || CACHE_PY="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/lib/cache-expiry.py"
  read -r EXP_AT EXP_TTL EXP_SRC < <(python3 "$CACHE_PY" "$TRANSCRIPT" 2>/dev/null)
  if [ -n "$EXP_AT" ]; then
    LEFT=$(( EXP_AT - $(date +%s) ))
    if [ "$LEFT" -le 0 ]; then
      CACHE="${C_RED}cache ✗${C_RESET}"
    else
      LM=$(( LEFT / 60 )); LS=$(( LEFT % 60 ))
      if   [ "$LM" -lt 5 ];  then CC="$C_ORANGE"
      elif [ "$LM" -lt 15 ]; then CC="$C_YELLOW"
      else                        CC="$C_GREEN"; fi
      if [ "$LM" -gt 0 ]; then LTXT="${LM}m"; else LTXT="${LS}s"; fi
      # ⌛ = kdy to spadne; /5m nebo /1h = jaké okno se na to platí.
      case "$EXP_TTL" in 60) WIN="1h" ;; *) WIN="${EXP_TTL}m" ;; esac
      CACHE="${CC}cache ${LTXT}${C_RESET}${C_LABEL} (⌛$(date -r "$EXP_AT" +%H:%M 2>/dev/null)/${WIN})${C_RESET}"
    fi
  fi
fi

# --- Orca worktree --------------------------------------------------------
# Který chlíveček v Orce to je + jeho card status. Orca CLI je RPC do appky
# (~150 ms), takže se NIKDY nevolá synchronně: render bere hodnotu z cache
# a když je starší než ORCA_TTL, sáhne na obnovu na pozadí. Statusline tím
# nikdy nečeká; nejhůř ukáže stav o jeden render starý.
ORCA_SEG=""
if command -v orca >/dev/null 2>&1; then
  ORCA_TTL=20
  ORCA_CACHE="${TMPDIR:-/tmp}/claude-statusline-orca.$(id -u).$(printf '%s' "$PWD" | md5 -q 2>/dev/null || printf '%s' "$PWD" | md5sum | cut -d' ' -f1)"
  AGE=99999
  if [ -f "$ORCA_CACHE" ]; then
    M=$(stat -f %m "$ORCA_CACHE" 2>/dev/null || stat -c %Y "$ORCA_CACHE" 2>/dev/null)
    [ -n "$M" ] && AGE=$(( $(date +%s) - M ))
  fi
  if [ "$AGE" -gt "$ORCA_TTL" ]; then
    ( orca worktree current --json 2>/dev/null \
        | jq -r 'if .ok then (.result.worktree // .result) | "\(.displayName // "")\t\(.workspaceStatus // "")" else "" end' 2>/dev/null \
        > "$ORCA_CACHE.tmp" && mv -f "$ORCA_CACHE.tmp" "$ORCA_CACHE" ) >/dev/null 2>&1 &
    disown 2>/dev/null
  fi
  if [ -f "$ORCA_CACHE" ]; then
    IFS=$'\t' read -r OW_NAME OW_STATUS < "$ORCA_CACHE"
    if [ -n "$OW_NAME" ]; then
      case "$OW_STATUS" in
        todo)        OS_GLYPH="○"; OS_COLOR="$C_LABEL" ;;
        in-progress) OS_GLYPH="◐"; OS_COLOR="$C_YELLOW" ;;
        in-review)   OS_GLYPH="◔"; OS_COLOR="$C_BLUE" ;;
        completed)   OS_GLYPH="●"; OS_COLOR="$C_GREEN" ;;
        *)           OS_GLYPH="";  OS_COLOR="$C_LABEL" ;;
      esac
      # Jméno se skryje, když je stejné jako branch — nemá cenu ho psát dvakrát.
      if [ "$OW_NAME" = "$BRANCH" ]; then
        ORCA_SEG="${C_MAGENTA}⛵${C_RESET}${OS_COLOR}${OS_GLYPH}${C_RESET}"
      else
        ORCA_SEG="${C_MAGENTA}⛵ ${OW_NAME}${C_RESET}${OS_COLOR}${OS_GLYPH}${C_RESET}"
      fi
    fi
  fi
fi

# Format a Unix-epoch reset time; empty when the field is absent (-1) or unparsable.
# $1 = epoch, $2 = date format (e.g. %H:%M for 5h, %d.%m for 7d).
fmt_reset() {
  [ "$1" -ge 0 ] 2>/dev/null || return 0
  date -r "$1" +"$2" 2>/dev/null
}

# Rate-limit value — empty when both fields are missing (segment hides itself).
# Shows used % and, when available, when the window resets: 5h:12% ⟳14:30
# Predikce: lineárně z dosavadního tempa v okně (start = reset − délka okna).
# Když se 100 % stihne dřív než reset, vypíše červeně ⚠HH:MM; jinak šedě →N %,
# kolik bude při resetu. Prvních 15 minut okna mlčí, odhad by byl šum.
# $1 = used %, $2 = reset epoch, $3 = okno v s, $4 = formát.
predict_full() {
  [ "$1" -gt 0 ] 2>/dev/null && [ "$2" -gt 0 ] 2>/dev/null || return 0
  local now start elapsed eta
  now=$(date +%s); start=$(( $2 - $3 )); elapsed=$(( now - start ))
  [ "$elapsed" -ge 900 ] || return 0
  eta=$(( start + elapsed * 100 / $1 ))
  if [ "$eta" -lt "$2" ]; then
    printf '%s⚠%s%s' "$C_RED" "$(date -r "$eta" +"$4" 2>/dev/null)" "$C_RESET"
  else
    printf '%s→%d%%%s' "$C_LABEL" $(( $1 * $3 / elapsed )) "$C_RESET"
  fi
}

RL=""
if [ "$RL5" -ge 0 ]; then
  RL="$(pct_color "$RL5")5h:${RL5}%${C_RESET}"
  R=$(fmt_reset "$RL5R" "%H:%M"); [ -n "$R" ] && RL="${RL}${C_LABEL}⟳${R}${C_RESET}"
  P=$(predict_full "$RL5" "$RL5R" 18000 "%H:%M"); [ -n "$P" ] && RL="${RL} ${P}"
fi
if [ "$RL7" -ge 0 ]; then
  [ -n "$RL" ] && RL="${RL} · "
  RL="${RL}$(pct_color "$RL7")7d:${RL7}%${C_RESET}"
  R=$(fmt_reset "$RL7R" "%d.%m"); [ -n "$R" ] && RL="${RL}${C_LABEL}⟳${R}${C_RESET}"
  P=$(predict_full "$RL7" "$RL7R" 604800 "%d.%m %H:%M"); [ -n "$P" ] && RL="${RL} ${P}"
fi

# Assemble (dva řádky, zlom za kontextem):
#   «INSTANCE» [model effort] | 📁 dir | 🌿 branch | Context: <bar> % (tokeny)
#   Limits: 5h/7d s predikcí | cache | orca
printf "%s%s[%s]%s | 📁 %s | 🌿 %s | %sContext:%s %s%s%s %s%d%%%s %s(%dk/%dk)%s" \
  "$BADGE" "$C_CYAN" "$MODEL_LABEL" "$C_RESET" "$DIR" "$GIT" \
  "$C_LABEL" "$C_RESET" "$PC" "$BAR" "$C_RESET" "$PC" "$PERCENT" "$C_RESET" \
  "$C_LABEL" "$TOKENS_K" "$(( CTX_BUDGET / 1000 ))" "$C_RESET"
LINE2=""
[ -n "$RL" ]       && LINE2="${C_LABEL}Limits:${C_RESET} ${RL}"
[ -n "$CACHE" ]    && LINE2="${LINE2:+$LINE2 | }${CACHE}"
[ -n "$ORCA_SEG" ] && LINE2="${LINE2:+$LINE2 | }${ORCA_SEG}"
[ -n "$LINE2" ] && printf "\n%s" "$LINE2"
exit 0
