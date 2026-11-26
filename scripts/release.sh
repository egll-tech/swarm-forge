#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_NAME="get-swarm-forge"
FORMULA_PATH="Formula/swarm-forge.rb"
REPO="egll/swarm-forge"          # ← adjust
REMOTE="${REMOTE:-origin}"
SCRIPT_DIR="${0:A:h}"

usage() {
  cat <<EOF >&2
Usage: $0 (--major | --minor | --patch | --version X.Y.Z) [--force] [--skip-fetch]
       $0 --unrelease X.Y.Z

  --major / --minor / --patch   bump from the latest remote tag
  --version X.Y.Z               use an explicit version
  --force                       overwrite existing tag (only with --version)
  --skip-fetch                  do not fetch remote tags
  --unrelease X.Y.Z             delegate to scripts/unrelease
EOF
  exit 1
}

# ---------- args ----------
BUMP=""
EXPLICIT=""
FORCE=false
SKIP_FETCH=false
UNRELEASE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --major)      BUMP=major; shift ;;
    --minor)      BUMP=minor; shift ;;
    --patch)      BUMP=patch; shift ;;
    --version)    EXPLICIT=$2; shift 2 ;;
    --force)      FORCE=true; shift ;;
    --skip-fetch) SKIP_FETCH=true; shift ;;
    --unrelease)  UNRELEASE=$2; shift 2 ;;
    -h|--help)    usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

# Delegate unrelease to the dedicated script
if [[ -n $UNRELEASE ]]; then
  exec "$SCRIPT_DIR/unrelease.sh" "$UNRELEASE" --remote "$REMOTE"
fi

# ---------- release logic ----------
if [[ -z $BUMP && -z $EXPLICIT ]]; then
  echo "Error: must give --major, --minor, --patch, or --version" >&2
  usage
fi

if [[ $FORCE == true && -z $EXPLICIT ]]; then
  echo "Error: --force is only allowed with --version" >&2
  exit 1
fi

if [[ $SKIP_FETCH == false ]]; then
  echo "Fetching tags from $REMOTE..."
  git fetch --tags "$REMOTE"
fi

latest_tag() {
  git tag -l 'v*' --sort=-v:refname | head -n1
}

bump() {
  local current=$1 part=$2
  local major minor patch
  IFS=. read -r major minor patch <<<"${current#v}"
  case $part in
    major) major=$((major+1)); minor=0; patch=0 ;;
    minor) minor=$((minor+1)); patch=0 ;;
    patch) patch=$((patch+1)) ;;
  esac
  echo "${major}.${minor}.${patch}"
}

if [[ -n $EXPLICIT ]]; then
  NEW_VERSION=$EXPLICIT
else
  LATEST=$(latest_tag || true)
  if [[ -z $LATEST ]]; then
    echo "No tags found. Starting at 0.1.0"
    CURRENT=0.0.0
  else
    CURRENT=${LATEST#v}
    echo "Latest tag: $LATEST"
  fi
  NEW_VERSION=$(bump "$CURRENT" "$BUMP")
fi

TAG="v${NEW_VERSION}"
echo "Releasing $TAG"

if git rev-parse "$TAG" >/dev/null 2>&1; then
  if [[ $FORCE == true ]]; then
    echo "Deleting existing local tag $TAG (--force)"
    git tag -d "$TAG"
  else
    echo "Tag $TAG already exists."
    read -r "?Overwrite? [y/N] " reply
    [[ $reply =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
    git tag -d "$TAG"
  fi
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Error: working tree is not clean." >&2
  exit 1
fi

SHA256=$(git show "HEAD:${SCRIPT_NAME}" | shasum -a 256 | awk '{print $1}')
echo "sha256: $SHA256"

if [[ ! -f $FORMULA_PATH ]]; then
  echo "Error: $FORMULA_PATH not found" >&2
  exit 1
fi

sed -i.bak \
  -e "s/\(version \)\"[^\"]*\"/\1\"${NEW_VERSION}\"/" \
  -e "s/\(sha256 \)\"[^\"]*\"/\1\"${SHA256}\"/" \
  "$FORMULA_PATH"
rm -f "${FORMULA_PATH}.bak"

echo "Formula updated:"
grep -E '^\s*(version|sha256)' "$FORMULA_PATH"

git add "$FORMULA_PATH"
git commit -m "chore(formula): release ${TAG}"

git tag -a "$TAG" -m "Release ${TAG}"

echo "Pushing tag..."
git push "$REMOTE" "$TAG"

echo
echo "Released $TAG (tag pushed)"
echo "Users: brew upgrade egll/swarm-forge"