# STEAL THE TREASURE

Social treasure-extraction game for Roblox.
**Find something valuable. Get it home. Don't get caught.**

## Project layout (Rojo)

| Path | Roblox location | Purpose |
|---|---|---|
| `src/shared` | `ReplicatedStorage.Shared` | Config (balance, treasures, gadgets, world layout), pure logic, remotes |
| `src/server` | `ServerScriptService.Server` | Authoritative services + procedural world builder |
| `src/client` | `StarterPlayerScripts.Client` | HUD, menus, effects (presentation + input only) |
| `tests` | — | Lune unit tests for pure logic + compile check |

Balance lives in `src/shared/Config/GameConfig.luau`. Treasures in `Treasures.luau`,
gadgets in `Gadgets.luau`, guardians in `Guardians.luau`, positions in `WorldLayout.luau`.

## Develop

Tools (see `aftman.toml`): rojo, selene, stylua, lune.

```sh
rojo serve                 # live-sync into Studio (Rojo plugin)
rojo build -o build/game.rbxl
stylua src tests           # format
selene src                 # lint
lune run tests/run         # unit tests
lune run tests/compile     # syntax check every file
rojo sourcemap -o sourcemap.json && luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json src
```

Studio: enable *Game Settings → Security → Enable Studio Access to API Services* to test saving;
without it the game runs with temporary data.

## CI / publishing

`.github/workflows/ci.yml` runs format, lint, compile, tests and a Rojo build on every push/PR.
On pushes (not PRs) it publishes the build to the **test place** via Open Cloud using the
`SAT_PUBLISHING_KEY` secret and the `ROBLOX_TEST_UNIVERSE_ID` / `ROBLOX_TEST_PLACE_ID` variables.

Manual place settings (not settable from code): Max Players = 10, avatar type, genre, icon.

Current status: see `docs/DEV_STATUS.md`.
