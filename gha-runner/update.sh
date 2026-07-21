#!/bin/bash
set -euo pipefail

RUNNER_VERSION="${1:-}"
if [ -z "${RUNNER_VERSION}" ]; then
  echo "Usage: ./update.sh <RUNNER_VERSION>"
  echo "Example: ./update.sh 2.336.0"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"
PROJECT_NAME="$(basename "${SCRIPT_DIR}")"

shopt -s nullglob
compose_files=(docker-compose.*.yml)
if [ ${#compose_files[@]} -eq 0 ]; then
  echo "Error: no docker-compose.*.yml files found"
  exit 1
fi

count_replicas() {
  local service="$1"
  docker ps -a --format '{{.Names}}' | grep -c "${PROJECT_NAME}-${service}-" || true
}

echo "Building github-runner:${RUNNER_VERSION}..."
docker build --build-arg RUNNER_VERSION="${RUNNER_VERSION}" -t "github-runner:${RUNNER_VERSION}" .

echo "Updating .env with RUNNER_VERSION=${RUNNER_VERSION}"
if [ -f .env ] && grep -q '^RUNNER_VERSION=' .env; then
  sed -i "s/^RUNNER_VERSION=.*/RUNNER_VERSION=${RUNNER_VERSION}/" .env
else
  echo "RUNNER_VERSION=${RUNNER_VERSION}" >>.env
fi

recreated_any=false
for compose_file in "${compose_files[@]}"; do
  mapfile -t services < <(docker compose -f "${compose_file}" config --services)
  if [ ${#services[@]} -eq 0 ]; then
    echo "Skipping ${compose_file} (no services)"
    continue
  fi

  scale_args=()
  for service in "${services[@]}"; do
    scale="$(count_replicas "${service}")"
    echo "  ${compose_file} / ${service}: scale=${scale}"
    if [ "${scale}" -gt 0 ]; then
      scale_args+=(--scale "${service}=${scale}")
    fi
  done

  if [ ${#scale_args[@]} -eq 0 ]; then
    echo "Skipping ${compose_file} (all services at scale 0)"
    continue
  fi

  echo "Recreating ${compose_file}..."
  docker compose -f "${compose_file}" up -d "${scale_args[@]}" --force-recreate --remove-orphans
  recreated_any=true
done

if [ "${recreated_any}" = true ]; then
  echo "Removing old github-runner images..."
  while IFS= read -r image; do
    [ -z "${image}" ] && continue
    if [ "${image}" = "github-runner:${RUNNER_VERSION}" ]; then
      continue
    fi
    echo "  docker rmi ${image}"
    docker rmi "${image}" || echo "  Warning: could not remove ${image} (may still be in use)"
  done < <(docker images "github-runner" --format '{{.Repository}}:{{.Tag}}' | grep -v '<none>')
else
  echo "No fleets were recreated; leaving existing github-runner images in place."
fi

echo "Done. Runners are on github-runner:${RUNNER_VERSION}"
