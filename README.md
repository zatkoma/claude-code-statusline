# claude-code-statusline

Status line pro [Claude Code](https://claude.com/claude-code) na dva řádky. Ukazuje
model, složku, git, zaplnění kontextu, limity předplatného **s predikcí, kdy dojdou**,
a za jak dlouho vyprší prompt cache.

```
«🏢 WORK» [Opus 5.5[1m] Med] | 📁 muj-projekt | 🌿 main ↑2 +1~3?1 | Context: ███░░░░░░░ 38% (152k/400k)
Limits: 5h:60%⟳11:25 ⚠10:35 · 7d:20%⟳05.11 →59% | cache 42m (⌛09:54/1h) | ⛵◐
```

Vychází z [faborsky/claude-code-statusline](https://github.com/faborsky/claude-code-statusline)
(MIT, Jindřich Fáborský), který stojí na tutoriálu Leonarda Grigoria.

## Co ukazuje

**1. řádek**

| Segment | Význam |
|---|---|
| `«🏢 WORK»` | badge instance, když jedeš víc profilů najednou ([níže](#badge-instance)); ve výchozím `~/.claude` se neukazuje |
| `[Opus 5.5[1m] Med]` | model, `[1m]` = 1M kontext, effort (Low/Med/High/XHigh/Max) |
| `📁 muj-projekt` | aktuální složka |
| `🌿 main ↑2 ↓1 +1~3?1⚑1` | branch, commity napřed/pozadu vůči upstreamu, `+` staged, `~` změněné, `?` nové, `⚑` stash |
| `Context: ███░░ 38% (152k/400k)` | tokeny v kontextu vůči rozpočtu **400k**, ne vůči celému oknu modelu |

**2. řádek**

| Segment | Význam |
|---|---|
| `5h:60%⟳11:25` | využití 5h limitu a kdy se resetuje |
| `⚠10:35` | **červeně:** při dosavadním tempu dojde limit v 10:35, ještě před resetem |
| `→59%` | **šedě:** při dosavadním tempu budeš mít při resetu vyčerpáno 59 % |
| `7d:20%⟳05.11` | totéž pro týdenní limit |
| `cache 42m (⌛09:54/1h)` | za kolik minut vyprší prompt cache, v kolik a jaké okno (5m/1h) se platí |
| `⛵ název◐` | worktree v Orce a jeho stav (○ todo, ◐ rozpracované, ◔ review, ● hotovo); jen když je nainstalované `orca` CLI |

Limity se ukazují jen s předplatným Pro/Max/Team. Bez nich se segment skryje, stejně
jako cache nebo Orca, když nejsou k dispozici.

### Proč kontext vůči 400k

S 1M oknem by procenta dlouho ukazovala skoro nulu a nic by neřekla. 400k je
zvolená hranice, kdy začít novou session. Nad ní jde ukazatel přes 100 %. Změníš ji proměnnou `CLAUDE_CTX_BUDGET` (v tokenech).

### Jak se počítá predikce

Lineárně z dosavadního tempa v okně: začátek okna = reset − délka okna (5 h, 7 dní).
Prvních 15 minut okna predikce mlčí, odhad by byl jen šum.

### Jak se pozná vypršení cache

`lib/cache-expiry.py` čte konec transcriptu session a bere skutečně naúčtované
`usage.cache_creation`. Podle toho pozná, jestli se cache zapsala na 5 minut, nebo
na hodinu, a od posledního requestu dopočítá vypršení. Nic se nehádá. Ručně se dá
TTL přebít proměnnou `CLAUDE_CACHE_TTL_MIN` (v minutách).

## Požadavky

- macOS (používá BSD `date -r` a `stat -f`)
- `jq` (`brew install jq`)
- `python3` (segment cache)
- `git` (volitelně, mimo repo ukáže `no-git`)

## Instalace

```bash
git clone https://github.com/zatkoma/claude-code-statusline.git ~/.claude/claude-code-statusline
```

Do `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/claude-code-statusline/statusline.sh",
    "refreshInterval": 10
  }
}
```

`refreshInterval` je v sekundách. Bez něj se status line překreslí jen při aktivitě,
takže odpočet cache a predikce stojí na místě, když se nic neděje.

Aktualizace: `git -C ~/.claude/claude-code-statusline pull`.

Skript si `lib/cache-expiry.py` hledá vedle sebe, takže repo může ležet kdekoli.

## Badge instance

Když spouštíš víc profilů Claude Code přes `CLAUDE_CONFIG_DIR` (třeba pracovní
a osobní), badge na začátku řádku ukáže, ve kterém session běží:

| Config dir | Badge |
|---|---|
| `~/.claude` (výchozí) | žádný |
| `~/.claude-work` | `«🏢 WORK»` modře |
| `~/.claude-personal` | `«🏠 PERSONAL»` zeleně |
| cokoli jiného, např. `~/.claude-foo` | `«⚙ claude-foo»` fialově |

Vlastní název a barva přes `env` v `settings.json` daného profilu:

```json
{
  "env": {
    "CLAUDE_INSTANCE": "🧪 LAB",
    "CLAUDE_INSTANCE_COLOR": "\u001b[35m"
  }
}
```

## Proměnné

| Proměnná | Výchozí | K čemu |
|---|---|---|
| `CLAUDE_CTX_BUDGET` | `400000` | rozpočet kontextu pro procenta |
| `CLAUDE_CACHE_TTL_MIN` | — | ruční TTL cache v minutách |
| `CLAUDE_INSTANCE` | podle config diru | text badge |
| `CLAUDE_INSTANCE_COLOR` | podle config diru | ANSI barva badge |

## Výkon

Status line se spouští často, proto nic nečeká na síť:

- git je jedno volání `git status --porcelain=v2`, bez fetchování
- `cache-expiry.py` čte jen posledních 512 kB transcriptu
- `orca` CLI se volá na pozadí a výsledek se drží 20 s v cache

## Licence

MIT, viz [LICENSE](LICENSE).
