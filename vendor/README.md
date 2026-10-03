# Vendored Zig Dependencies

These packages were fetched from their upstream repositories with `zig fetch` and are kept in-tree
because none of them supports Zig 0.17.0 yet. They are wired up as path dependencies from
`build.zig.zon` (and from `vendor/httpz/build.zig.zon` for the transitive dependencies).

| Directory   | Upstream                                       | Commit                                     |
| ----------- | ---------------------------------------------- | ------------------------------------------ |
| `zul`       | https://github.com/karlseguin/zul              | `146f9d5b2238c3a621b96345adf03490900c2fe2` |
| `httpz`     | https://github.com/karlseguin/http.zig         | `52eb187cff75e168316b44480cd9f0fae26a1c5e` |
| `metrics`   | https://github.com/karlseguin/metrics.zig      | `6de29b83a750a06c438d268543e0e3c3c1b309da` |
| `websocket` | https://github.com/karlseguin/websocket.zig    | `b70e733bc0d0ba0a98ff5fe5ef64d3017c85f369` |

## Applied Patches (Zig 0.17.0)

Everything below is a mechanical 0.17.0 migration; no behavior was intentionally changed.

- `b.args` is gone. Run steps use `addPassthruArgs()`
  (`httpz/build.zig`, `metrics/build.zig`).
- Array/string multiplication (`a ** b`) is gone, replaced by `@splat`
  (`httpz/src/httpz.zig`, `httpz/src/request.zig`, `httpz/src/response.zig`,
  `httpz/test_runner.zig`, `websocket/src/websocket.zig`, `zul/src/uuid.zig`,
  `zul/src/ulid.zig`, `zul/test_runner.zig`).
- `@typeInfo` is now struct-of-arrays: `.fields` -> `.field_types` / `.field_names`,
  `.params` -> `.param_types`, `.Fn.params` -> `.Fn.param_types`
  (`httpz/src/thread_pool.zig`, `httpz/src/httpz.zig`, `httpz/src/router.zig`,
  `httpz/src/testing.zig`, `websocket/src/server/server.zig`,
  `websocket/src/server/thread_pool.zig`, `websocket/src/client/client.zig`,
  `zul/src/arc.zig`, `zul/src/scheduler.zig`, `zul/src/testing.zig`).
- `std.meta.fields` is deprecated -> `@typeInfo(T).@"struct".field_types`.
- `std.meta.Int` was replaced by the `@Int(.unsigned, bits)` builtin
  (`httpz/src/url.zig`).
- `std.ascii.indexOfIgnoreCase` was replaced by `std.ascii.findIgnoreCase`
  (`httpz/src/httpz.zig`).
- `std.testing.allocator_instance` is now a `std.heap.SafeAllocator` that is
  `.init(...)`-ed per test and whose `deinit()` returns a leak count instead of an
  enum (`httpz/test_runner.zig`, `zul/test_runner.zig`).

## Review Upstream Regularly - Then Un-Vendor

Vendoring is a temporary workaround, not a permanent arrangement. Check every package above
against the Zig version in `build.zig.zon` (`.minimum_zig_version`) on a regular basis - at least
whenever the toolchain is bumped, and periodically in between (for example when checking
dependabot-style updates or when touching the build).

For each package, check the upstream repository for a commit that supports the current Zig version:

```sh
curl -s https://raw.githubusercontent.com/karlseguin/http.zig/master/build.zig.zon | grep minimum_zig_version
curl -s https://api.github.com/repos/karlseguin/http.zig/commits?per_page=5 | jq -r '.[] | "\(.sha) \(.commit.author.date) \(.commit.message | split("\n")[0])"'
```

As soon as a package supports the current Zig version, un-vendor it:

1. `zig fetch --save <archive-url>` the newer upstream revision.
2. Point the dependency back at `.url` + `.hash` in `build.zig.zon` (and in
   `vendor/httpz/build.zig.zon` for `metrics` / `websocket`).
3. Re-apply only the patches from "Applied Patches" that the upstream version still needs, and drop
   the vendored directory.
4. Re-run `zig build`, `zig build test`, `zig build all` and the smoke test, then delete this file
   once no package remains vendored.

Do not let a vendored copy drift far behind upstream: re-fetch it whenever upstream ships a bug fix
that this project relies on, so the patches above stay short and reviewable.
