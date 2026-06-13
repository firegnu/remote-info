#!/usr/bin/env bash
set -euo pipefail

staged_files="$(mktemp)"
trap 'rm -f "$staged_files"' EXIT

git diff --cached --name-only -z --diff-filter=ACM |
  while IFS= read -r -d '' file; do
    if [[ "$file" == "script/check_no_secrets.sh" ]]; then
      continue
    fi
    printf '%s\0' "$file"
  done >"$staged_files"

if [[ ! -s "$staged_files" ]]; then
  exit 0
fi

if xargs -0 rg -n --pcre2 -- \
  '-----BEGIN (RSA |DSA |EC |OPENSSH )?PRIVATE KEY-----|ghp_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|AWS_SECRET_ACCESS_KEY|AKIA[0-9A-Z]{16}|IdentityFile\s+~?/|OPENAI_API_KEY\s*[:=]\s*["'\'']?[^"'\''[:space:]#]+|sk-[A-Za-z0-9_-]{20,}|(?i)\b(token|password|passphrase)\s*[:=]\s*["'\'']?[^"'\''[:space:]#]+' \
  <"$staged_files"; then
  echo "Potential secret found in staged files. Remove it before committing." >&2
  exit 1
fi
