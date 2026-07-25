# claude-code-statusline

Můj status line pro [Claude Code](https://claude.com/claude-code) — na jeden řádek
ukazuje **kterou instanci mám spuštěnou**, model, složku, git branch, zaplnění
context window a využití 5h / 7denních limitů.

```
«🏢 WORK» [Opus 4.8 ·low] | 📁 muj-projekt | 🌿 main± | Context: ██░░░░░░░░ 23% | Limits: 5h:12% ⟳17:30 · 7d:40% ⟳28.07
```

Základ převzat z [faborsky/claude-code-statusline](https://github.com/faborsky/claude-code-statusline)
(a jeho zdroje – tutoriál Leonarda Grigoria). Doplněno o **badge instance** na
začátku řádku, abych při více běžících Claudech (pracovní / osobní) hned viděl,
ve které konfiguraci session běží.

## Co ukazuje

| Segment | Význam |
|---|---|
| `«🏢 WORK»` | **instance** — podle config diru (viz níže), barevně odlišená |
| `[Opus 4.8 ·low]` | model + reasoning effort (effort se skryje, když chybí) |
| `📁 muj-projekt` | aktuální složka |
| `🌿 main±` | git branch; `±` = necommitnuté změny; `no-git` mimo repo |
| `Context: ██░░░ 23%` | zaplnění context window (10 segmentů, barevně dle %) |
| `Limits: 5h:12% ⟳17:30 · 7d:40% ⟳28.07` | využití limitů + čas/datum obnovení (`⟳`) — **jen s Pro/Max předplatným**, jinak se skryje |

## Požadavky

- `jq` (`brew install jq`)
- `git` (volitelné — mimo repo ukáže `no-git`)

## Instalace

```bash
# 1) skript umísti kamkoli, např. do config diru
cp statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

```jsonc
// 2) v settings.json dané instance (~/.claude/settings.json apod.)
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
```

Restartuj session — status line se načítá při startu.

> **Tip:** jeden a týž skript zvládne obě instance. Ukaž na něj z obou
> `settings.json` — badge se přepne sám podle toho, v jakém config diru běží.

## Rozlišení instance (badge)

Badge se určuje v tomto pořadí:

1. **`$CLAUDE_INSTANCE`** (a volitelně `$CLAUDE_INSTANCE_COLOR`) — explicitní název,
   nastavený přes `env` v `settings.json`. Má přednost.
2. Jinak **podle `$CLAUDE_CONFIG_DIR`**:
   - `.claude-work` → `🏢 WORK` (modrá)
   - `.claude` → `🏠 PERSONAL` (zelená)
   - cokoli jiného → `⚙ <název>` (fialová)

Vlastní název a barva:

```jsonc
// settings.json
{
  "env": {
    "CLAUDE_INSTANCE": "🏢 SEZNAM",
    "CLAUDE_INSTANCE_COLOR": "[35m"   // ANSI escape (35 = fialová)
  }
}
```

Chování badge upravíš přímo v `statusline.sh` v bloku `--- Instance badge ---`.

## Použití napříč projekty

Skript i napojení leží v **config diru** (`settings.json`), ne v projektu —
takže platí ve **všech** projektech dané instance automaticky. Stačí nastavit
jednou.
