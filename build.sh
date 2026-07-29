#!/usr/bin/env bash
# Rebuild the docker image, then delete the image it replaced.
set -euo pipefail

CIB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CIB_ROOT/config.env"
[[ -n "${IMAGE_NAME:-}" ]] || { echo "build.sh: IMAGE_NAME is not set in config.env" >&2; exit 1; }

# What we are about to replace. Empty on a first build, which is fine.
old="$(docker image inspect "$IMAGE_NAME" --format '{{.Id}}' 2>/dev/null || true)"

# Build before removing anything: a failed build must leave the old image usable.
#   --pull      refreshes the floating Node 22 LTS base image tag
#   --no-cache  reinstalls Claude Code from the @stable channel
docker build --pull --no-cache -t "$IMAGE_NAME" "$CIB_ROOT"

# Drop the now-untagged predecessor; the ID compare avoids deleting an unchanged rebuild.
new="$(docker image inspect "$IMAGE_NAME" --format '{{.Id}}')"
if [[ -n "$old" && "$old" != "$new" ]]; then
  if docker image rm "$old" >/dev/null 2>&1; then
    echo "build.sh: removed replaced image ${old:7:12}"
  else
    echo "build.sh: could not remove ${old:7:12} — still referenced by a container" >&2
  fi
fi

echo "build.sh: $IMAGE_NAME now runs $(docker run --rm "$IMAGE_NAME" --version)"
