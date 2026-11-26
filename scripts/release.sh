#!/usr/bin/env zsh
set -euo pipefail

FORMULA_PATH="Formula/swarm-forge.rb"
REPO="egll-tech/swarm-forge"
REMOTE="${REMOTE:-origin}"
SCRIPT_DIR="${0:A:h}"
cd "${SCRIPT_DIR:h}"

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

BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ $BRANCH != main ]]; then
  echo "Error: release must be run from main (currently ${BRANCH})." >&2
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

if [[ ! -f $FORMULA_PATH ]]; then
  echo "Error: $FORMULA_PATH not found" >&2
  exit 1
fi

file_sha256() {
  local file=$1
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  else
    echo "Error: need shasum or sha256sum" >&2
    exit 1
  fi
}

sed -i.bak \
  -e "s/\(version \)\"[^\"]*\"/\1\"${NEW_VERSION}\"/" \
  "$FORMULA_PATH"
rm -f "${FORMULA_PATH}.bak"

echo "Formula version updated:"
grep -E '^\s*(version|sha256|url)' "$FORMULA_PATH"

git add "$FORMULA_PATH"
git commit -m "chore(formula): release ${TAG}"

git tag -a "$TAG" -m "Release ${TAG}"

echo "Pushing ${BRANCH} and ${TAG}..."
git push "$REMOTE" HEAD
git push "$REMOTE" "$TAG"

ARCHIVE_URL="https://github.com/${REPO}/archive/refs/tags/${TAG}.tar.gz"
ARCHIVE=$(mktemp)
trap 'rm -f "$ARCHIVE" "${ARCHIVE}.list"' EXIT

echo "Downloading ${ARCHIVE_URL}"
downloaded=false
for attempt in 1 2 3 4 5 6; do
  if curl -fsSL "$ARCHIVE_URL" -o "$ARCHIVE"; then
    downloaded=true
    break
  fi
  echo "Archive not ready (attempt ${attempt}); retrying..."
  sleep $((attempt * 2))
done
if [[ $downloaded != true ]]; then
  echo "Error: failed to download ${ARCHIVE_URL}" >&2
  exit 1
fi

# Save the listing. grep -q in a pipe can SIGPIPE tar, and pipefail would
# then treat a complete archive as missing the installer.
tar -tzf "$ARCHIVE" >"${ARCHIVE}.list"
if ! grep -q 'bin/get-swarm-forge$' "${ARCHIVE}.list"; then
  echo "Error: ${TAG} archive is missing bin/get-swarm-forge" >&2
  exit 1
fi

SHA256=$(file_sha256 "$ARCHIVE")
echo "sha256: $SHA256"

sed -i.bak \
  -e "s/\(sha256 \)\"[^\"]*\"/\1\"${SHA256}\"/" \
  "$FORMULA_PATH"
rm -f "${FORMULA_PATH}.bak"

echo "Formula checksum updated:"
grep -E '^\s*(version|sha256)' "$FORMULA_PATH"

git add "$FORMULA_PATH"
git commit -m "chore(formula): pin sha256 for ${TAG}"
git push "$REMOTE" HEAD

echo "Updating homebrew branch..."
homebrew_status=0
{
  git fetch "$REMOTE" homebrew
  git checkout -B homebrew "$REMOTE/homebrew"
  git checkout main -- "$FORMULA_PATH"
  git add "$FORMULA_PATH"
  if ! git diff --cached --quiet; then
    git commit -m "chore(formula): release ${TAG}"
  fi
  git push "$REMOTE" homebrew
} || homebrew_status=$?

git checkout main

if [[ $homebrew_status -ne 0 ]]; then
  echo "Error: failed to update the homebrew branch" >&2
  exit "$homebrew_status"
fi

echo
echo "Released ${TAG}"
echo "homebrew branch updated and pushed"
echo "Back on main"
echo "Users: brew upgrade swarm-forge"
