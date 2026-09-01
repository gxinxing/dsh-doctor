# dsh-doctor — Fix DeepSeek Harness `cannot resolve profile bundle` & web profile install failures (pnpm allowBuilds / ERR_PNPM_GIT_DEP_PREPARE / unsupported JSON schema)

> A tiny, dependency-free doctor for [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (`dsh`). One command tells you **why `dsh web` (or any profile) won't boot after an update**, and `dsh-doctor fix` repairs it.

If you landed here from a search for one of these errors, you're in the right place:

- `Error: dsh: cannot resolve profile bundle "@deepseek-ai/dsh-tool-read-prd" from the dsh installation or .../profiles/web`
- `ERR_PNPM_GIT_DEP_PREPARE_NOT_ALLOWED … needs to execute build scripts but is not in the "allowBuilds" allowlist`
- `unsupported JSON schema: schema.properties.metadata.required must be true when present`
- `unsupported JSON schema: schema.properties.metadata.additionalProperties must be explicitly true or false`
- `dsh plugin … pnpm not found` / `dsh plugin` hangs while downloading pnpm via corepack

**Keywords:** DeepSeek Harness, dsh, cannot resolve profile bundle, profile bundle, pnpm allowBuilds, ERR_PNPM_GIT_DEP_PREPARE_NOT_ALLOWED, git dependency commit drift, corepack pnpm shim hang, unsupported JSON schema, dsh-tools schema compiler, web profile install failed.

---

## Why this happens (the TL;DR)

Three safe-by-default behaviors stack up and **point the error at the wrong thing**:

1. **Unpinned git dependency + no lockfile** → every `pnpm install` re-resolves the git dep to a new commit.
2. **pnpm `allowBuilds` is fail-closed** → its allowlist key pins a commit hash; when the hash drifts, the *entire* install aborts, so `web/node_modules` is never built.
3. **Node's graceful module fallback** → with no local `node_modules`, resolution walks up to the parent profile dir, which only lacks your local `file:` plugin — so the error names *that* plugin, not the broken install.

Plus a second layer: once deps are back, a local plugin written for an older `dsh-tools` fails its stricter schema compiler (`required` must be `true`; objects need explicit `additionalProperties`).

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/gxinxing/dsh-doctor/main/doctor.sh -o dsh-doctor
chmod +x dsh-doctor
# or just clone:
git clone https://github.com/gxinxing/dsh-doctor.git && cd dsh-doctor
```

> Requires `bash` and a DeepSeek Harness install. No other dependencies.

## Usage

```bash
./doctor.sh            # read-only diagnosis of the web profile
./doctor.sh -p tui     # diagnose a different profile
./doctor.sh fix        # reinstall the profile's deps with a real pnpm
./doctor.sh -p headless fix
```

Sample output:

```
== dsh-doctor: profile 'web' ==
[OK]   dsh installed (0.1.1-rc.2)
[OK]   profile dir: ~/.deep-seek-harness-mcp/services/<hash>/profiles/web
[OK]   node_modules built
[OK]   @deepseek-ai/dsh-tool-read-prd installed
[OK]   pnpm-lock.yaml present (drift pinned)
[OK]   git dependency pinned (drift risk off)
[WARN] PATH pnpm is the corepack shim (dsh plugin hangs on it) — use ~/.npm-global/bin/pnpm
```

## What `doctor.sh` checks

| Check | Catches | Fix |
|-------|---------|-----|
| `node_modules` built | silent fallback masking a missing local plugin | `pnpm install` |
| local `file:` plugin present | `cannot resolve profile bundle` | `pnpm install` |
| `pnpm-lock.yaml` exists | repeatable installs (no drift) | commit it |
| git deps pinned | `ERR_PNPM_GIT_DEP_PREPARE_NOT_ALLOWED` | pin commit / use npm registry version |
| pnpm is real, not corepack | `dsh plugin` hangs downloading pnpm | use the real binary |

## How it locates things (no hardcoding)

- Harness home: `$DSH_HOME`, else `~/.deep-seek-harness-mcp`.
- Profile dir: the `services/<hash>/profiles/<name>` that owns the target profile's `package.json`.
- pnpm: prefers `~/.npm-global/bin/pnpm` (or `npm prefix -g`) over the corepack shim.

## The schema fix (for local plugins)

When you see `unsupported JSON schema`, edit your plugin's tool schema:

- every `object` must set `additionalProperties: true` (or `false`) explicitly;
- `required` may only be `true` when present (`required: false` is rejected).

## Contributing

PRs welcome — especially more error-class matchers. Keep it POSIX `bash`, zero dependencies.

## License

MIT — see [LICENSE](./LICENSE).
