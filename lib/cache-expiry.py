#!/usr/bin/env python3
"""Kdy vyprší prompt cache konverzace — podle toho, co API skutečně naúčtovalo.

Vypíše jeden řádek: <epoch_expirace> <ttl_minut> <zdroj>
Nic nenajde → nevypíše nic a skončí s 1.

Odkud se to bere: Claude Code si do transcriptu ukládá u každé odpovědi
`usage.cache_creation` s rozpadem `ephemeral_1h_input_tokens` /
`ephemeral_5m_input_tokens`. Nenulový kýbl říká, s jakým TTL se zápis do cache
platil (1h zápis stojí 2×, 5m 1,25× — tedy ta hodnota není odhad, je to
účtovaná skutečnost). Když turn jen čte z cache a nic nezapisuje, TTL se vezme
z posledního turnu, který zapisoval; čtení totiž okno posouvá, ne mění.

Kotva je `timestamp` posledního záznamu s usage, ne mtime souboru — do
transcriptu se dopisuje i po posledním requestu.

Ruční přebití: CLAUDE_CACHE_TTL_MIN (minuty) — pak se čte jen kotva.
"""
import json, os, sys
from datetime import datetime, timezone

TAIL = 512 * 1024   # stačí konec souboru, transcript roste na megabajty


def tail_lines(path, nbytes=TAIL):
    with open(path, "rb") as f:
        f.seek(0, os.SEEK_END)
        start = max(0, f.tell() - nbytes)
        f.seek(start)
        buf = f.read()
    if start:                       # první řádek je nejspíš půlka záznamu
        buf = buf.split(b"\n", 1)[-1]
    return buf.splitlines()


def main():
    if len(sys.argv) < 2:
        return 1
    path = sys.argv[1]
    if not os.path.isfile(path):
        return 1

    anchor = None       # čas posledního requestu
    ttl_min = None      # TTL z posledního zápisu do cache
    for raw in reversed(tail_lines(path)):
        try:
            d = json.loads(raw)
        except Exception:
            continue
        msg = d.get("message")
        usage = msg.get("usage") if isinstance(msg, dict) else None
        if not isinstance(usage, dict):
            continue
        if anchor is None and d.get("timestamp"):
            try:
                anchor = datetime.fromisoformat(
                    d["timestamp"].replace("Z", "+00:00")).timestamp()
            except Exception:
                pass
        if ttl_min is None:
            cc = usage.get("cache_creation") or {}
            # Když turn zapsal do obou kýblů, platí ten delší — cache drží
            # nejdéle podle nejdelšího zápisu v prefixu.
            if cc.get("ephemeral_1h_input_tokens"):
                ttl_min = 60
            elif cc.get("ephemeral_5m_input_tokens"):
                ttl_min = 5
        if anchor is not None and ttl_min is not None:
            break

    if anchor is None:
        anchor = os.path.getmtime(path)
        src = "mtime"
    else:
        src = "usage"

    env = os.environ.get("CLAUDE_CACHE_TTL_MIN")
    if env and env.strip().isdigit():
        ttl_min, src = int(env), "env"
    elif ttl_min is None:
        ttl_min, src = 5, "default"   # bez důkazu o 1h předpokládej kratší okno

    print(f"{int(anchor + ttl_min * 60)} {ttl_min} {src}")
    return 0


sys.exit(main())
