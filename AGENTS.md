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

## Vendored Dependencies - Check Upstream, Then Un-Vendor

`httpz` and `zul` (plus their transitive `metrics` and `websocket`) live in `vendor/` as path
dependencies instead of being fetched from the Zig package manager, because none of them supported
Zig 0.17.0 when this was last done. Each copy carries mechanical patches; see
[`vendor/README.md`](vendor/README.md) for the package/commit table, the full patch list, and the
un-vendoring checklist.

Treat vendoring as temporary. When you touch dependencies, bump the Zig version, or do routine
maintenance, check whether upstream has caught up:

```sh
curl -s https://raw.githubusercontent.com/karlseguin/http.zig/master/build.zig.zon | grep -E 'minimum_zig_version|fingerprint'
curl -s https://api.github.com/repos/karlseguin/http.zig/commits?per_page=5 \
  | jq -r '.[] | "\(.sha[0:12]) \(.commit.author.date) \(.commit.message | split("\n")[0])"'
```

Once a package supports the Zig version in `build.zig.zon`, un-vendor it: fetch the newer upstream
archive with `zig fetch --save`, switch the dependency back to `.url` + `.hash`, re-apply only the
patches that are still needed, delete the vendored directory, and verify with `zig build`,
`zig build test` and `zig build all`. Once nothing is vendored, delete `vendor/README.md`.

## Frontend Migration Notes

`MIGRATION_TASKS.md` tracks outstanding SvelteKit migration work; delete it once every task is
resolved.