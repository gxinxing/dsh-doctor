# Troubleshooting examples — real error logs & `dsh-doctor` output

Real failures seen after a DSH update, paired with what `./doctor.sh` reports and the exact fix. Paths are shortened for readability.

---

## 1. `cannot resolve profile bundle`

**Symptom (the boot error):**

```
Error: dsh: cannot resolve profile bundle "@deepseek-ai/dsh-tool-read-prd" from the dsh installation
  or /Users/.../services/<hash>/profiles/web; run 'dsh plugin --profile web install' if its
  dependency is not installed
    at resolveBundleDir (.../dsh-app-boot/lib/index.js:523:8)
    ...
Node.js v22.23.1
```

**What `doctor.sh` says:**

```
[OK]   dsh installed (0.1.1-rc.2)
[OK]   profile dir: ~/.deep-seek-harness-mcp/services/<hash>/profiles/web
[FAIL] node_modules missing — deps never installed. Fix: cd <dir> && ~/.npm-global/bin/pnpm install
[FAIL] read-prd bundle missing — reinstall: cd <dir> && ~/.npm-global/bin/pnpm install
```

**Root cause:** the profile's `node_modules` was never built, so Node walked up to the parent profile dir (which only lacks your local `file:` plugin) and blamed *that* plugin. The misleading hint `dsh plugin --profile web install` is a dead end — it hits the corepack pnpm shim and hangs.

**Fix:**

```bash
cd ~/.deep-seek-harness-mcp/services/<hash>/profiles/web
~/.npm-global/bin/pnpm install   # use the REAL pnpm, not the corepack shim
```

---

## 2. `ERR_PNPM_GIT_DEP_PREPARE_NOT_ALLOWED`

**Symptom (during install):**

```
[ERR_PNPM_GIT_DEP_PREPARE_NOT_ALLOWED] Failed to prepare git-hosted package fetched from
"https://codeload.github.com/dsh-market/dsh-market/tar.gz/ee95b359...":
The git-hosted package "dshmarket@1.39.0" needs to execute build scripts but is not in
the "allowBuilds" allowlist.
Add the package to "allowBuilds" in your project's pnpm-workspace.yaml to allow it to run scripts.
```

**What `doctor.sh` says:**

```
[WARN] unpinned git dependency — commit drifts, allowBuilds hash mismatches; pin it or use the npm registry version
```

**Root cause:** an unpinned `github:org/repo` dependency re-resolves to a new commit on every install, but `pnpm-workspace.yaml`'s `allowBuilds` key pins a commit hash. When the hash drifts, the *entire* install aborts (fail-closed).

**Fix (two options):**

```bash
# A) pin the commit to whatever allowBuilds already lists:
#    package.json -> "dshmarket": "github:dsh-market/dsh-market#<hash-from-allowBuilds>"
# B) switch to the npm registry version (no allowBuilds needed):
#    package.json -> "dshmarket": "1.39.0"
~/.npm-global/bin/pnpm install
```

---

## 3. `unsupported JSON schema` (local plugin vs new `dsh-tools`)

**Symptom (after deps come back):**

```
Error: dsh: plugin tree failed to load: ... tool-read-prd (@deepseek-ai/dsh-tool-read-prd):
unsupported JSON schema: schema.properties.metadata.required must be true when present
```

or the second variant once the first is fixed:

```
unsupported JSON schema: schema.properties.metadata.additionalProperties must be explicitly true or false
```

**Root cause:** a local plugin written for an older `dsh-tools` no longer satisfies the stricter schema compiler in the updated harness. `prerelease` versions don't promise backward compatibility.

**Fix (edit your plugin's tool schema):**

```js
// before
metadata: { type: "object", required: false, properties: { ... } }
// after
metadata: { type: "object", additionalProperties: true, properties: { ... } }
// rule: `required` may only be `true` when present; every object needs explicit `additionalProperties`
```

---

## TL;DR

| Error class | One-line fix |
|-------------|--------------|
| `cannot resolve profile bundle` | reinstall with the real pnpm |
| `ERR_PNPM_GIT_DEP_PREPARE_*` | pin the git dep / use the npm registry version |
| `unsupported JSON schema` | fix the local plugin's schema (additionalProperties, required:true) |
