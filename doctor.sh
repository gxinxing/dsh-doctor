#!/usr/bin/env bash
# dsh-doctor — diagnose & fix DeepSeek Harness (dsh) profile install failures.
#
# Solves the three failure modes that break `dsh web` (and other profiles) after
# a DSH update:
#   1. cannot resolve profile bundle  -> web/node_modules never built; graceful
#      Node fallback masks the missing local `file:` plugin
#   2. ERR_PNPM_GIT_DEP_PREPARE_NOT_ALLOWED -> a git dependency's commit drifted
#      and the pnpm allowBuilds hash no longer matches (fail-closed install)
#   3. unsupported JSON schema        -> a local plugin's tool schema no longer
#      satisfies the newer @deepseek-ai/dsh-tools compiler
#
# Usage:
#   dsh-doctor                 # read-only diagnosis of the web profile
#   dsh-doctor -p tui          # diagnose a different profile
#   dsh-doctor fix             # reinstall the profile's deps with a real pnpm
#   dsh-doctor -p headless fix # fix a specific profile
#
# The script never hardcodes paths: it resolves the harness home from $DSH_HOME
# (or ~/.deep-seek-harness-mcp), picks the service that owns the target profile,
# and prefers a real pnpm over the corepack shim that silently hangs.
set -uo pipefail

PROG="$(basename "$0")"
PROFILE="web"
MODE="check"

while [ $# -gt 0 ]; do
  case "$1" in
    -p|--profile) PROFILE="${2:-web}"; shift 2 ;;
    fix)          MODE="fix"; shift ;;
    -h|--help)    sed -n '2,24p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# ---- locate harness home -------------------------------------------------
if [ -n "${DSH_HOME:-}" ]; then
  HARNESS_HOME="$DSH_HOME"
elif [ -d "$HOME/.deep-seek-harness-mcp" ]; then
  HARNESS_HOME="$HOME/.deep-seek-harness-mcp"
else
  HARNESS_HOME=""  # resolved via dsh below if possible
fi

# ---- locate the profile dir (a service owns each profile set) ------------
PROFILE_DIR=""
if [ -n "$HARNESS_HOME" ] && [ -d "$HARNESS_HOME/services" ]; then
  for d in "$HARNESS_HOME"/services/*/profiles/"$PROFILE"; do
    [ -e "$d/package.json" ] && { PROFILE_DIR="$d"; break; }
  done
fi
if [ -z "$PROFILE_DIR" ] && [ -n "$HARNESS_HOME" ]; then
  PROFILE_DIR="$HARNESS_HOME/profiles/$PROFILE"   # single-profile fallback
fi

# ---- locate a real pnpm (corepack shim silently downloads & hangs) -------
PNPM=""
for c in "$HOME/.npm-global/bin/pnpm" "$(npm prefix -g 2>/dev/null)/bin/pnpm"; do
  [ -x "$c" ] && PNPM="$(command -v "$c")" && break
done
[ -z "$PNPM" ] && PNPM="pnpm"

ok()   { printf '[OK]   %s\n' "$1"; }
fail() { printf '[FAIL] %s\n' "$1"; }
warn() { printf '[WARN] %s\n' "$1"; }

echo "== dsh-doctor: profile '$PROFILE' =="

# 0. dsh itself
if command -v dsh >/dev/null 2>&1; then
  ok "dsh installed ($(dsh --version 2>/dev/null))"
else
  fail "dsh not found on PATH — install DeepSeek Harness first"
  exit 1
fi

# 1. profile located
if [ -n "$PROFILE_DIR" ] && [ -f "$PROFILE_DIR/package.json" ]; then
  ok "profile dir: $PROFILE_DIR"
else
  fail "cannot locate $PROFILE profile (DSH_HOME=$HARNESS_HOME)"; exit 1
fi

# 2. node_modules built?
if [ -d "$PROFILE_DIR/node_modules" ]; then
  ok "node_modules built"
else
  fail "node_modules missing — deps never installed. Fix: cd $PROFILE_DIR && $PNPM install"
fi

# 3. local file: plugin present?
READ_PRD="$PROFILE_DIR/node_modules/@deepseek-ai/dsh-tool-read-prd"
if [ -f "$READ_PRD/package.json" ]; then
  ok "@deepseek-ai/dsh-tool-read-prd installed"
else
  fail "read-prd bundle missing — reinstall: cd $PROFILE_DIR && $PNPM install"
fi

# 4. lockfile (no lockfile => every install re-resolves & git deps drift)
if [ -f "$PROFILE_DIR/pnpm-lock.yaml" ]; then
  ok "pnpm-lock.yaml present (drift pinned)"
else
  warn "no pnpm-lock.yaml — every install drifts; commit it after fixing"
fi

# 5. git deps pinned? (unpinned => commit drift => allowBuilds mismatch)
if grep -qE 'dsh-market/dsh-market#|github:.*#' "$PROFILE_DIR/package.json" 2>/dev/null; then
  ok "git dependency pinned (drift risk off)"
elif grep -qE 'dsh-market/dsh-market"|github:[^"]+"' "$PROFILE_DIR/package.json" 2>/dev/null; then
  warn "unpinned git dependency — commit drifts, allowBuilds hash mismatches; pin it or use the npm registry version"
fi

# 6. pnpm is real, not corepack shim
if [ "$(command -v pnpm 2>/dev/null)" = "$PNPM" ]; then
  ok "pnpm on PATH is the real binary ($PNPM)"
else
  warn "PATH pnpm is the corepack shim (dsh plugin hangs on it) — use $PNPM"
fi

echo
echo "== next =="
echo "  profile-layer check (no boot): dsh --profile $PROFILE --dump-config"
echo "  three error classes:"
echo "    cannot resolve bundle   -> cd $PROFILE_DIR && $PNPM install"
echo "    unsupported JSON schema -> fix local plugin: objects need additionalProperties (bool), required must be true if present"
echo "    ERR_PNPM_GIT_DEP_*       -> pin the git dep to the allowBuilds hash, then $PNPM install"

if [ "$MODE" = "fix" ]; then
  echo; echo "== running fix: reinstall deps =="
  cd "$PROFILE_DIR" || exit 1
  "$PNPM" install "$@"
fi
