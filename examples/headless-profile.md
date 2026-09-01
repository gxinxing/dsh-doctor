# Example: the `headless` profile

`dsh-doctor` is not web-only. The same failure modes hit `tui` and `headless` too — and the script auto-discovers which `services/<hash>/profiles/<name>` owns the target profile. Here is a real run against `headless`.

## Run

```bash
./doctor.sh -p headless
```

## Output

```
== dsh-doctor: profile 'headless' ==
[OK]   dsh installed (0.1.1-rc.2)
[OK]   profile dir: ~/.deep-seek-harness-mcp/services/<hash>/profiles/headless
[OK]   node_modules built
[OK]   @deepseek-ai/dsh-tool-read-prd installed
[OK]   pnpm-lock.yaml present (drift pinned)
[WARN] PATH pnpm is the corepack shim (dsh plugin hangs on it) — use ~/.npm-global/bin/pnpm
```

## What this proves

- **Auto-discovery works.** No path was hardcoded; the script found `services/<hash>/profiles/headless` on its own.
- **Per-profile accuracy.** `headless`'s `package.json` only declares the local `file:` plugin — it has *no* `dshmarket` git dependency, so the `unpinned git dependency` warning does **not** appear. (Compare with the `web` run, where that warning fires.) The checks are profile-specific, not global.
- **Same one-liner fix.** If it had failed, the fix would be `./doctor.sh -p headless fix`.

## Fix (if a profile is actually broken)

```bash
./doctor.sh -p headless fix
# equivalent to:
cd ~/.deep-seek-harness-mcp/services/<hash>/profiles/headless
~/.npm-global/bin/pnpm install
```
