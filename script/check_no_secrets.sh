#!/usr/bin/env bash
set -euo pipefail

secret_pattern='-----BEGIN (RSA |DSA |EC |OPENSSH )?PRIVATE KEY-----|ghp_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|AWS_SECRET_ACCESS_KEY|AKIA[0-9A-Z]{16}|IdentityFile\s+~?/|OPENAI_API_KEY\s*[:=]\s*["'\'']?[^"'\''[:space:]#]+|sk-[A-Za-z0-9_-]{20,}|(?i:\b(token|password|passphrase)\s*[:=]\s*["'\'']?[^"'\''[:space:]#]+)'

found=0
scan_output="$(mktemp)"
trap 'rm -f "$scan_output"' EXIT

while IFS= read -r -d '' file; do
  if [[ "$file" == "script/check_no_secrets.sh" ]]; then
    continue
  fi

  if git show ":$file" 2>/dev/null | rg -a -n --pcre2 -- "$secret_pattern" - >"$scan_output"; then
    echo "$file"
    cat "$scan_output"
    found=1
  fi
done < <(git diff --cached --name-only -z --diff-filter=ACM)

if [[ "$found" -ne 0 ]]; then
  echo "Potential secret found in staged files. Remove it before committing." >&2
  exit 1
fi
