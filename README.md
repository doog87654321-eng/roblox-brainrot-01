[![make.fun](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/doog87654321-eng/roblox-brainrot-01/rank.svg)](https://make.fun/bounty/roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/doog87654321-eng/roblox-brainrot-01/reward.svg)](https://make.fun/bounty/roblox-brainrot-01)

# Brainrot Bay — Steal a Brainrot, survive the wave

A 3D Roblox brainrot game for make.fun's [roblox-brainrot-01](https://make.fun/bounty/roblox-brainrot-01)
bounty: collect absurd meme characters off the conveyor belt, park them on
your base, and watch the cash tick up — while other players try to steal
them and a tsunami sweeps the map every three minutes.

## How to play

- **Buy brainrots off the belt.** They walk the conveyor from the green pad
  to the red one. Click one in the shop (or its prompt) to buy it onto your
  base — if you can afford it before it walks away.
- **Earn every second.** Each brainrot pays its $/s into your cash, forever.
  Rarer ones pay more: Common → Rare → Epic → Legendary → Mythic →
  Brainrot God → Secret.
- **Chase mutations.** Spawns can roll Golden (x2), Diamond (x5) or Rainbow
  (x10) — same character, multiplied price and income, glowing shell.
- **Steal — and get stolen from.** Walk up to a brainrot on someone else's
  base and take it. A $500 base lock keeps thieves out for 60 seconds, and
  stealing has a 30-second cooldown.
- **Rebirth.** Cash in everything at $25,000 (then $150,000, $750,000…)
  for a permanent x2 income multiplier that stacks.
- **Survive the tsunami.** Every 3 minutes a wave warning sounds. Get back
  inside your base before the wall sweeps past you, or lose 10% of your cash
  — and every brainrot still on the belt is washed away.

## The cast

12 original characters, from Noodle Nibbler ($2/s) to The Algorithm ($1,200/s):
Sir Bananaphone, Capybara CEO, DJ Pickle, Toilet Tornado, Grandma's WiFi,
Shark in a Suit, Professor Pigeon, The Infinite Burrito, Quantum Quokka,
Lord Loo Roll and The Algorithm.

## Layout

- `default.project.json` — the Rojo project: the island, four base plots, the
  conveyor, the ocean, palms, lamps and the totem.
- `src/shared/BrainrotCatalog.luau` — the cast, rarities and mutations.
- `src/shared/GameConfig.luau` — every tuning number in one place.
- `src/server/init.server.luau` — the game: spawning, buying, income,
  stealing, locks, rebirths and the tsunami.
- `src/client/Game.client.luau` — the HUD: cash bar, belt shop, lock/rebirth
  buttons, toasts and the tsunami banner.
- `main.ts` — the entrypoint: copies the game to `/output` and writes
  `dossier.json` with the vendored make.fun library.
- `game.rbxl` — the place, built with `rojo build`.

## Build it

```sh
rojo build default.project.json --output game.rbxl
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

## Status

Built and verified on Linux (Rojo 7.5.1, Luau compiles clean, place reads
92 instances with 100% src/ coverage). Not yet published: publishing needs a
Roblox account that can already make an experience Public — see PLAY.json,
which still holds placeholder ids until the game is published from Studio.
