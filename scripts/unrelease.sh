#!/usr/bin/env zsh
set -euo pipefail

REMOTE="${REMOTE:-origin}"

usage() {
  cat <<EOF >&2
Usage: $0 <version> [--remote REMOTE]

  Deletes the tag v<version> locally and on the remote, then pushes the deletion.
EOF
  exit 1
}

[[ $# -ge 1 ]] || usage

VERSION=$1
shift
while [[ $# -gt 0 ]]; do
  case $1 in
    --remote) REMOTE=$2; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

TAG="v${VERSION}"
echo "Unreleasing $TAG"

read -r "?Delete tag $TAG locally and on $REMOTE? [y/N] " reply
[[ $reply =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }

if git rev-parse "$TAG" >/dev/null 2>&1; then
  git tag -d "$TAG"
else
  echo "Local tag $TAG does not exist"
fi

# Push deletion (git surfaces any auth prompts; errors are not hidden)
git push "$REMOTE" --delete "$TAG"

echo
echo "Tag $TAG deleted and deletion pushed."
echo "If the formula still references this version, update it and push,"
echo "or release a corrected version."
echo "Users who installed it should: brew reinstall --force egll/swarm-forge"