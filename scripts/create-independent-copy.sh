#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: ./scripts/create-independent-copy.sh DESTINATION [GIT_REMOTE_URL]

Create a clean, independent Git repository from the tracked project files.
The destination must be absent or empty. Build output, .env, imported external
repositories, and the source repository's Git history are not copied.

If GIT_REMOTE_URL is supplied, it is added as the new repository's origin.
This script never pushes to a remote.
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
    usage >&2
    exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
destination="$1"
remote_url="${2:-}"

if ! git -C "${repo_root}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: ${repo_root} is not a Git worktree." >&2
    exit 1
fi

if [[ -e "${destination}" && ! -d "${destination}" ]]; then
    echo "Error: destination exists and is not a directory: ${destination}" >&2
    exit 1
fi

if [[ -d "${destination}" ]] && find "${destination}" -mindepth 1 -print -quit | grep -q .; then
    echo "Error: destination is not empty: ${destination}" >&2
    exit 1
fi

mkdir -p "${destination}"
destination="$(cd "${destination}" && pwd)"

case "${destination}/" in
    "${repo_root}/"*)
        echo "Error: destination cannot be inside the source repository." >&2
        exit 1
        ;;
esac

# Export the current versions of tracked files only. This includes intentional
# local edits while excluding ignored externals, build output, .env, and .git.
# A tracked file may be intentionally deleted in the current working tree. Filter
# those index entries so the copy reflects the current project, not just HEAD.
git -C "${repo_root}" ls-files -z --cached --others --exclude-standard \
    | while IFS= read -r -d '' path; do
        if [[ -e "${repo_root}/${path}" || -L "${repo_root}/${path}" ]]; then
            printf '%s\0' "${path}"
        fi
      done \
    | tar -C "${repo_root}" --null -T - -cf - \
    | tar -xf - -C "${destination}"

upstream_url="$(git -C "${repo_root}" remote get-url origin 2>/dev/null || printf 'unknown')"
upstream_commit="$(git -C "${repo_root}" rev-parse HEAD)"

{
    printf '# Project origin\n\n'
    printf 'This repository was created as an independent working copy of:\n\n'
    printf -- '- Source: `%s`\n' "${upstream_url}"
    printf -- '- Source commit: `%s`\n\n' "${upstream_commit}"
    printf 'The original BSD-3-Clause license and copyright notice are retained in `LICENSE`.\n'
    printf 'Third-party components imported through `workspace.repos` retain their own licenses.\n'
} > "${destination}/ORIGIN.md"

git -C "${destination}" init -b main
git -C "${destination}" add --all
git -C "${destination}" commit -m "Initial independent project import"

if [[ -n "${remote_url}" ]]; then
    git -C "${destination}" remote add origin "${remote_url}"
fi

printf '\nIndependent repository created at: %s\n' "${destination}"
if [[ -n "${remote_url}" ]]; then
    printf 'Remote configured (not pushed): %s\n' "${remote_url}"
else
    printf 'No remote configured. Add one with:\n'
    printf '  git -C %q remote add origin <your-github-repository-url>\n' "${destination}"
fi
