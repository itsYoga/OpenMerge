#!/usr/bin/env bash
# Print the delta context for a change, replacing `openspec show --deltas-only`,
# which cannot run against this project's custom schema (see
# docs/openspec-compatibility.md).
#
# This reads OpenSpec's own status output and the artifact files on disk. It does
# not reimplement OpenSpec's parser and must not grow into one.
#
# Usage: scripts/openspec-context.sh <change-name>

set -euo pipefail

change="${1:-}"
if [[ -z "$change" ]]; then
  echo "usage: $(basename "$0") <change-name>" >&2
  echo >&2
  echo "active changes:" >&2
  openspec list >&2 || true
  exit 64
fi

repo_root="$(git rev-parse --show-toplevel)"
change_dir="$repo_root/openspec/changes/$change"

if [[ ! -d "$change_dir" ]]; then
  echo "no such change: $change" >&2
  echo "expected at: $change_dir" >&2
  exit 66
fi

echo "=== artifact status ==="
openspec status --change "$change"

echo
echo "=== artifacts present ==="
find "$change_dir" -name '*.md' -type f \
  | sed "s|^$change_dir/||" \
  | sort \
  | while read -r f; do
      printf '%-28s %5s lines\n' "$f" "$(wc -l <"$change_dir/$f" | tr -d ' ')"
    done

echo
echo "=== delta specs ==="
if [[ -d "$change_dir/specs" ]]; then
  for spec in "$change_dir"/specs/*/spec.md; do
    [[ -e "$spec" ]] || continue
    capability="$(basename "$(dirname "$spec")")"
    reqs="$(grep -c '^### Requirement:' "$spec" || true)"
    scens="$(grep -c '^#### Scenario:' "$spec" || true)"
    printf '%-30s %2s requirements  %3s scenarios\n' "$capability" "$reqs" "$scens"
    grep '^### Requirement:' "$spec" | sed 's/^### Requirement:/    -/'
  done
else
  echo "(none yet)"
fi

echo
echo "=== validation ==="
openspec validate "$change" --strict

echo
echo "=== uncommitted changes under this change ==="
# `git diff` alone would miss untracked files, which is how a brand-new artifact
# reads as "clean". --porcelain covers staged, unstaged, and untracked in one pass.
status="$(git -C "$repo_root" status --porcelain -- "$change_dir")"
if [[ -z "$status" ]]; then
  echo "(clean)"
else
  echo "$status"
fi
