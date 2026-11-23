#!/usr/bin/env bash
#
# update-jian-bing-liu-tag.sh
# Updates the web container image tag for Jian Bing Liu in ProjectDesk-GitOps.

set -euo pipefail

IMAGE_TAG="${1:-}"
ENV="${2:-staging}"

if [[ -z "$IMAGE_TAG" ]]; then
  echo "Usage: $0 <image_tag> [environment: staging|prod]" >&2
  exit 1
fi

if [[ "$ENV" != "staging" && "$ENV" != "prod" ]]; then
  echo "Unsupported environment: $ENV (expected staging or prod)" >&2
  exit 1
fi

if [[ ! "$IMAGE_TAG" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
  echo "Invalid image tag: $IMAGE_TAG" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
file="${ROOT_DIR}/helm/jian-bing-liu/values-${ENV}.yaml"

if [[ ! -f "$file" ]]; then
  echo "Missing values file: $file" >&2
  exit 1
fi

echo "Updating jian-bing-liu web tag to ${IMAGE_TAG} in ${ENV} environment..."
echo "  -> Updating $file"

awk -v tag="$IMAGE_TAG" '
  /^[^ ]/ { section=$1 }
  section == "web:" && $1 == "tag:" {
    q=sprintf("%c",34)
    print "  tag: " q tag q
    next
  }
  { print }
' "$file" > "${file}.tmp"
mv "${file}.tmp" "$file"

echo "Done! Run 'git diff' to review changes."
