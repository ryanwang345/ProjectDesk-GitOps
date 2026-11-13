#!/usr/bin/env bash
#
# update-image-tag.sh
# Updates container image tags in ProjectDesk-GitOps values files.

set -euo pipefail

COMPONENT="${1:-web+api}"
IMAGE_TAG="${2:-}"
ENV="${3:-dev}"

if [[ -z "$IMAGE_TAG" ]]; then
  echo "Usage: $0 <component: web|api|web+api> <image_tag> [environment: dev|staging|prod]"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

UPDATE_WEB="false"
UPDATE_API="false"
if [[ "$COMPONENT" == "web+api" || "$COMPONENT" == "all" ]]; then
  UPDATE_WEB="true"
  UPDATE_API="true"
elif [[ "$COMPONENT" == "web" ]]; then
  UPDATE_WEB="true"
elif [[ "$COMPONENT" == "api" ]]; then
  UPDATE_API="true"
fi

FILES_TO_UPDATE=()
[[ -f "${ROOT_DIR}/helm/values.yaml" ]] && FILES_TO_UPDATE+=("${ROOT_DIR}/helm/values.yaml")
[[ -f "${ROOT_DIR}/helm/values-${ENV}.yaml" ]] && FILES_TO_UPDATE+=("${ROOT_DIR}/helm/values-${ENV}.yaml")
[[ -f "${ROOT_DIR}/web/argo/values/${ENV}.yaml" && "$UPDATE_WEB" == "true" ]] && FILES_TO_UPDATE+=("${ROOT_DIR}/web/argo/values/${ENV}.yaml")
[[ -f "${ROOT_DIR}/api/argo/values/${ENV}.yaml" && "$UPDATE_API" == "true" ]] && FILES_TO_UPDATE+=("${ROOT_DIR}/api/argo/values/${ENV}.yaml")

echo "Updating ${COMPONENT} tag to ${IMAGE_TAG} in ${ENV} environment..."

for file in "${FILES_TO_UPDATE[@]}"; do
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
    $1 == "tag:" && updateWeb == "true" && section == "" {
      q=sprintf("%c",34)
      print "  tag: " q tag q
      next
    }
    { print }
  ' "$file" > "${file}.tmp"
  mv "${file}.tmp" "$file"
done

echo "Done! Run 'git diff' to review changes."
