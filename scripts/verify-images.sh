#!/usr/bin/env bash
#
# verify-images.sh
# Modeled after /Users/rwang/vail-projects/deployment-configuration/verify-images.sh
# Verifies all container images referenced in GitOps values files exist on Docker Hub.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -t 1 ]]; then
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  BOLD=$'\033[1m'
  RESET=$'\033[0m'
else
  RED=''
  GREEN=''
  BOLD=''
  RESET=''
fi

collect_images() {
  # Collect images from helm/values*.yaml and */argo/values/*.yaml
  for file in "${ROOT_DIR}"/helm/values*.yaml "${ROOT_DIR}"/*/argo/values/*.yaml; do
    [[ -f "$file" ]] || continue
    awk '
      /^api:/ { section="api" }
      /^web:/ { section="web" }
      /^postgres:/ { section="postgres" }
      /^[^ ]/ && $1 !~ /^(api:|web:|postgres:)/ { section="" }

      section != "" && /^[ ]+image:/ {
        repo=$2
        gsub(/^[ "]+|[ "]+$/, "", repo)
      }
      section != "" && /^[ ]+tag:/ {
        tag=$2
        gsub(/^[ "]+|[ "]+$/, "", tag)
        if (repo != "" && tag != "") {
          print repo ":" tag
          repo=""
          tag=""
        }
      }
    ' "$file"
  done | sort -u
}

verify_image() {
  local image="$1"
  # Standardize docker.io prefix
  local clean_image="${image#docker.io/}"
  local repo="${clean_image%:*}"
  local tag="${clean_image##*:}"

  echo -n "Verifying ${image} ... "

  # 1. Try skopeo if installed
  if command -v skopeo >/dev/null 2>&1; then
    if skopeo inspect --raw "docker://${image}" >/dev/null 2>&1; then
      echo "${GREEN}OK (skopeo)${RESET}"
      return 0
    fi
  fi

  # 2. Try Docker Registry API v2 with anonymous token
  local token_url="https://auth.docker.io/token?service=registry.docker.io&scope=repository:${repo}:pull"
  local token
  token=$(curl -sSL "$token_url" | grep -o '"token":"[^"]*"' | cut -d'"' -f4 || true)

  if [[ -n "$token" ]]; then
    local check_code
    check_code=$(curl -s -o /dev/null -w "%{http_code}" \
      -H "Authorization: Bearer ${token}" \
      -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
      "https://registry-1.docker.io/v2/${repo}/manifests/${tag}" || echo "000")

    if [[ "$check_code" == "200" ]]; then
      echo "${GREEN}OK (registry v2)${RESET}"
      return 0
    fi
  fi

  echo "${RED}${BOLD}MISSING OR UNAVAILABLE${RESET}" >&2
  return 1
}

main() {
  local image_count=0
  local missing=()

  echo "=========================================================="
  echo "ProjectDesk-GitOps Image Verification"
  echo "=========================================================="

  local images=()
  while IFS= read -r img; do
    [[ -z "$img" ]] && continue
    images+=("$img")
  done < <(collect_images)

  image_count=${#images[@]}
  if [[ $image_count -eq 0 ]]; then
    echo "No images found in values files." >&2
    exit 1
  fi

  echo "Found ${image_count} unique image(s) across GitOps values files:"
  for img in "${images[@]}"; do
    echo "  - ${img}"
  done
  echo

  for img in "${images[@]}"; do
    if ! verify_image "$img"; then
      missing+=("$img")
    fi
  done

  echo
  if [[ ${#missing[@]} -ne 0 ]]; then
    echo "${RED}${BOLD}Verification Failed! Missing image(s):${RESET}" >&2
    for img in "${missing[@]}"; do
      echo "  - ${RED}${img}${RESET}" >&2
    done
    exit 1
  fi

  echo "${GREEN}All images verified successfully in registry.${RESET}"
}

main "$@"
