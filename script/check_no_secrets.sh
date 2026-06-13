#!/usr/bin/env bash
set -euo pipefail

staged_files="$(git diff --cached --name-only --diff-filter=ACM | grep -Ev '(^script/check_no_secrets.sh$|^docs/superpowers/plans/)' || true)"

if [[ -z "$staged_files" ]]; then
  exit 0
fi

if printf '%s\n' "$staged_files" | xargs rg -n --pcre2 -- \
  '-----BEGIN (RSA |DSA |EC |OPENSSH )?PRIVATE KEY-----|ghp_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|AWS_SECRET_ACCESS_KEY|AKIA[0-9A-Z]{16}|IdentityFile\s+~?/' ; then
  echo "Potential secret found in staged files. Remove it before committing." >&2
  exit 1
fi
