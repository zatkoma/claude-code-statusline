# Claude Code statusline

[🇬🇧 English](README.md) · **🇨🇿 Čeština**

Dvouřádková **status line pro [Claude Code](https://claude.com/claude-code)**. Neukazuje
jen, kolik limitu máš vyčerpáno, ale **kdy ti při současném tempu dojde**, a za jak dlouho
vyprší prompt cache. K tomu model, složku, podrobný git a zaplnění kontextu. Pro každého,
kdo jede dlouhé session na předplatném a chce zeď vidět dřív, než do ní narazí.

Autor: Martin Žatkovič, postaveno na [faborsky/claude-code-statusline](https://github.com/faborsky/claude-code-statusline).

```
«🏢 WORK» [Opus 5.5[1m] Med] | 📁 muj-projekt | 🌿 main ↑2 +1~3?1 | Context: ███░░░░░░░ 38% (152k/400k)
Limits: 5h:60%⟳11:25 ⚠10:35 · 7d:20%⟳05.11 →59% | cache 42m (⌛09:54/1h) | ⛵◐
```

## Co ukazuje

**1. řádek: kde jsi**

| Část | Význam |
|---|---|
| `«🏢 WORK»` | **badge instance**: ve kterém profilu Claude Code session běží, když jich máš víc ([níže](#badge-instance)). Ve výchozím `~/.claude` se neukazuje |
| `[Opus 5.5[1m] Med]` | model, `[1m]` = 1M kontextové okno, reasoning effort (`Low` / `Med` / `High` / `XHigh` / `Max`) |
| `📁 muj-projekt` | aktuální složka |
| `🌿 main ↑2 ↓1 +1~3?1⚑1` | git branch, commity napřed/pozadu vůči upstreamu, `+` staged, `~` změněné, `?` nové, `⚑` stash; mimo repo `no-git` |
| `Context: ███░░ 38% (152k/400k)` | tokeny v kontextu vůči **rozpočtu 400k**, ne vůči celému oknu modelu ([proč](#proc-400k)) |

**2. řádek: jak dlouho ještě můžeš jet**

| Část | Význam |
|---|---|
| `5h:60%⟳11:25` | využití pětihodinového limitu a v kolik se resetuje |
| `⚠10:35` | **červeně:** při dosavadním tempu narazíš na 100 % v 10:35, *ještě před* resetem |
| `→59%` | **šedě:** při dosavadním tempu budeš při resetu na 59 %, takže v pohodě |
| `7d:20%⟳05.11` | totéž pro týdenní limit, reset jako datum |
| `cache 42m (⌛09:54/1h)` | **prompt cache**: za kolik minut vyprší, v kolik a jaké TTL se platilo (`5m` nebo `1h`). `cache ✗` = vypršela, další zpráva zaplatí celé načtení znovu |
| `⛵ název◐` | worktree v Orce a stav jeho karty (`○` todo, `◐` rozpracované, `◔` review, `●` hotovo); jen když je nainstalované `orca` CLI |

Barvy pro kontext a limity:

- 🟢 zelená < 50 %
- 🟡 žlutá ≥ 50 %
- 🟠 oranžová ≥ 70 %
- 🔴 červená ≥ 90 %

Odpočet cache zežloutne pod 15 minut a zoranžoví pod 5.

Každá část 2. řádku se skryje, když nemá co ukázat: limity jen s předplatným Pro/Max/Team
a až po první odpovědi v session, cache až když existuje transcript, Orca jen s jejím CLI.
Když je 2. řádek prázdný, zbude jeden.

## Požadavky

- **macOS**: skript používá BSD `date -r` a `stat -f`. Linux a Windows zatím nejsou podporované
- **[`jq`](https://jqlang.github.io/jq/)**: čte JSON, který Claude Code posílá na stdin (`brew install jq`)
- **python3**: pro segment cache (je součástí Xcode command line tools)
- **git**: volitelně; mimo repo ukáže `no-git`

> Status line se spouští často, takže v ní nic nečeká na síť: git je jedno volání
> `git status --porcelain=v2` bez fetchování, `cache-expiry.py` čte jen posledních
> 512 kB transcriptu a `orca` CLI se volá na pozadí s výsledkem drženým 20 sekund.

## Instalace

1. Naklonuj repo, třeba do config diru Claude Code:

   ```bash
   git clone https://github.com/zatkoma/claude-code-statusline.git ~/.claude/claude-code-statusline
   ```

   Skript si `lib/cache-expiry.py` najde vedle sebe, takže umístění je libovolné.

2. Zapni ho v `~/.claude/settings.json`:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/claude-code-statusline/statusline.sh",
       "refreshInterval": 10
     }
   }
   ```

   `refreshInterval` (v sekundách) je tu důležitý: bez něj se status line překreslí jen
   při aktivitě, takže odpočet cache a predikce stojí, když nic neděláš.

3. Otevři novou session a status line se objeví dole.

Aktualizace: `git -C ~/.claude/claude-code-statusline pull`.

## Badge instance

Když spouštíš víc profilů Claude Code přes `CLAUDE_CONFIG_DIR` (třeba pracovní
a osobní), badge ukáže, ke kterému session patří:

| Config dir | Badge |
|---|---|
| `~/.claude` (výchozí) | žádný |
| `~/.claude-work` | `«🏢 WORK»` modře |
| `~/.claude-personal` | `«🏠 PERSONAL»` zeleně |
| cokoli jiného, např. `~/.claude-lab` | `«⚙ claude-lab»` fialově |

Vlastní název a barva přes `env` v `settings.json` daného profilu:

```json
{
  "env": {
    "CLAUDE_INSTANCE": "🧪 LAB",
    "CLAUDE_INSTANCE_COLOR": "\u001b[35m"
  }
}
```

## Úpravy

Proměnné prostředí:

| Proměnná | Výchozí | K čemu |
|---|---|---|
| `CLAUDE_CTX_BUDGET` | `400000` | rozpočet kontextu, vůči kterému se počítají procenta |
| `CLAUDE_CACHE_TTL_MIN` | — | vynutí TTL cache v minutách místo čtení z transcriptu |
| `CLAUDE_INSTANCE` | podle config diru | text badge |
| `CLAUDE_INSTANCE_COLOR` | podle config diru | ANSI barva badge |

Ve skriptu:

- **Barevné prahy**: hodnoty `50 / 70 / 90` ve funkci `pct_color`.
- **Mapování badge**: blok `case "$CFG"` v sekci *Instance badge*.
- **Rozjezd predikce**: `900` sekund ve funkci `predict_full`, po které predikce mlčí.
- **Obnova Orcy**: `ORCA_TTL` v sekci *Orca worktree*.
- **Rozložení a pořadí**: sekce *Assemble* na konci souboru.

## Jak se to počítá

**Kontext.** Tokeny posledního requestu, `input + cache_creation + cache_read`
z `context_window.current_usage`, záložně `used_percentage × velikost okna`. Celý payload
se čte **jedním** průchodem `jq`.

<a id="proc-400k"></a>**Proč 400k.** S 1M oknem by procenta většinu session ukazovala skoro
nulu a nic by neřekla. 400k je zvolená hranice, kdy se vyplatí začít novou session. Nad ní
jde ukazatel přes 100 %. Změníš ji přes `CLAUDE_CTX_BUDGET`.

**Predikce.** Lineárně z dosavadního tempa v okně: začátek okna = reset − délka okna (5 h
nebo 7 dní). Když 100 % přijde před resetem, ukáže se červené `⚠čas`, jinak šedé `→N%`,
kde budeš při resetu. Prvních 15 minut okna predikce mlčí, odhad by byl jen šum.

**Cache.** `lib/cache-expiry.py` čte z transcriptu session `usage.cache_creation`, tedy to,
co API skutečně naúčtovalo. Nenulové `ephemeral_1h_input_tokens` znamená hodinový zápis
do cache, `ephemeral_5m_input_tokens` pětiminutový. Vypršení se počítá od času posledního
requestu, protože každé čtení z cache okno prodlužuje. Nic se nehádá.

## Poděkování

Postaveno na [claude-code-statusline](https://github.com/faborsky/claude-code-statusline)
od **Jindřicha Fáborského** (MIT), které vychází z tutoriálu **Leonarda Grigoria** *„My
actual Claude Code workflow“*. Tahle verze přidává badge instance, dva řádky, predikce
limitů, odpočet cache, podrobný git, rozpočet kontextu 400k a segment Orcy.

## Licence

[MIT](LICENSE) © 2026 Jindřich Fáborský, Martin Žatkovič.
