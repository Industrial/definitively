#!/usr/bin/env bash
# Conventional commit message gate (commit-msg hook).
# Matches commitizen-style types without a Python/uv dependency (NixOS-safe).
set -euo pipefail

msg_file="${1:?commit message file required}"
subject="$(sed -n '1p' "$msg_file" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

if [[ -z "$subject" ]]; then
    echo "commit-msg: empty subject line" >&2
    exit 1
fi

pattern='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([[:alnum:]._/-]+\))?!?: .+'

if [[ ! "$subject" =~ $pattern ]]; then
    cat >&2 <<EOF
commit-msg: subject must follow conventional commits.

  type(scope)?: description

Examples:
  feat: add workflow engine
  fix(definitively): handle missing final state
  docs: document moon quality gates

Got:
  $subject
EOF
    exit 1
fi
