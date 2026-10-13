# Agent Notes

Guess Quest = SvelteKit frontend + Zig WebSocket/HTTP server (`src/server`). The server embeds the
built frontend from `src/server/_static`, which is generated and gitignored.

## Commands

```sh
pnpm run build:frontend          # required first: generates src/server/_static
zig build                       # native debug server -> zig-out/bin/guessquest-server
zig build start -- -p 8080      # run it (args are passed through to the binary)
zig build test                  # unit tests (protocol + bit_io)
zig build all                   # release cross-compile for every release target
pnpm run dev                    # frontend + backend in parallel
```

`zig build` fails if `src/server/_static` is missing, so always build the frontend first.

This repo uses **pnpm** (`packageManager` pins the version); there is no `package-lock.json`.

## Zig Version

The Zig version is pinned in four places and must stay in sync:

- `build.zig.zon` -> `.minimum_zig_version`
- `.github/workflows/ci.yml` and `.github/workflows/cd.yml` -> `Setup Zig` step
- `Dockerfile` -> `zvm install <version>`
- `README.md` -> "Build from Source"

## Dependencies

All third-party packages are fetched from their upstream repositories by the Zig package manager -
`httpz` (https://github.com/karlseguin/http.zig) for the HTTP/WebSocket server and `zdt`
(https://codeberg.org/FObersteiner/zdt) for UTC log timestamps. Both are pinned by commit in
`build.zig.zon` (`.url` + `.hash`); bump them with `zig fetch --save <archive-url>` and verify with
`zig build`, `zig build test` and `zig build all`.

## Frontend Migration Notes

`MIGRATION_TASKS.md` tracks outstanding SvelteKit migration work; delete it once every task is
resolved.