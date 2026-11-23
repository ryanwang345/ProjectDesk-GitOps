#!/usr/bin/env bash
#
# update-image-tag.sh
# Updates container image tags in ProjectDesk-GitOps values files.

set -euo pipefail

COMPONENT="${1:-web+api}"
IMAGE_TAG="${2:-}"
ENV="${3:-staging}"

if [[ -z "$IMAGE_TAG" ]]; then
  echo "Usage: $0 <component: web|api|web+api> <image_tag> [environment: staging|prod]"
  exit 1
fi

if [[ "$ENV" != "staging" && "$ENV" != "prod" ]]; then
  echo "Unsupported environment: $ENV (expected staging or prod)" >&2
  exit 1
fi
if [[ "$COMPONENT" != "web" && "$COMPONENT" != "api" && "$COMPONENT" != "web+api" ]]; then
  echo "Unsupported component: $COMPONENT" >&2
  exit 1
fi
if [[ ! "$IMAGE_TAG" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
  echo "Invalid image tag: $IMAGE_TAG" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

UPDATE_WEB="false"
UPDATE_API="false"
if [[ "$COMPONENT" == "web+api" ]]; then
  UPDATE_WEB="true"
  UPDATE_API="true"
elif [[ "$COMPONENT" == "web" ]]; then
  UPDATE_WEB="true"
elif [[ "$COMPONENT" == "api" ]]; then
  UPDATE_API="true"
fi

file="${ROOT_DIR}/helm/project-desk/values-${ENV}.yaml"
if [[ ! -f "$file" ]]; then
  echo "Missing values file: $file" >&2
  exit 1
fi

echo "Updating ${COMPONENT} tag to ${IMAGE_TAG} in ${ENV} environment..."
echo "  -> Updating $file"
awk -v tag="$IMAGE_TAG" -v updateWeb="$UPDATE_WEB" -v updateApi="$UPDATE_API" '
  /^[^ ]/ { section=$1 }
  section == "api:" && $1 == "tag:" && updateApi == "true" {
    q=sprintf("%c",34)
    print "  tag: " q tag q
    next
  }
  section == "web:" && $1 == "tag:" && updateWeb == "true" {
    q=sprintf("%c",34)
    print "  tag: " q tag q
    next
  }
  { print }
' "$file" > "${file}.tmp"
mv "${file}.tmp" "$file"

echo "Done! Run 'git diff' to review changes."
