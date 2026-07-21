#!/bin/bash
set -euo pipefail

TARGET="${1:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"
PROJECT_NAME="$(basename "${SCRIPT_DIR}")"

if [ ! -f .env ] || ! grep -q '^RUNNER_VERSION=' .env; then
  echo "Error: .env with RUNNER_VERSION is required. Run ./update.sh <version> first."
  exit 1
fi

# shellcheck disable=SC1091
source .env

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

list_available() {
  echo "Available:"
  for file in "${compose_files[@]}"; do
    stem="${file#docker-compose.}"
    stem="${stem%.yml}"
    mapfile -t services < <(docker compose -f "${file}" config --services)
    for svc in "${services[@]}"; do
      echo "  ${stem} / ${svc}  (${file})"
    done
  done
}

resolve_target() {
  local want="$1"
  for file in "${compose_files[@]}"; do
    stem="${file#docker-compose.}"
    stem="${stem%.yml}"
    mapfile -t services < <(docker compose -f "${file}" config --services)
    for svc in "${services[@]}"; do
      if [ "${svc}" = "${want}" ] || [ "${stem}" = "${want}" ]; then
        echo "${file} ${svc}"
        return 0
      fi
    done
  done
  return 1
}

restart_compose() {
  local compose_file="$1"
  shift
  local -a services=("$@")

  if [ ${#services[@]} -eq 0 ]; then
    echo "Skipping ${compose_file} (no services)"
    return
  fi

  local scale_args=()
  local service scale
  for service in "${services[@]}"; do
    scale="$(count_replicas "${service}")"
    echo "  ${compose_file} / ${service}: scale=${scale}"
    if [ "${scale}" -gt 0 ]; then
      scale_args+=(--scale "${service}=${scale}")
    fi
  done

  if [ ${#scale_args[@]} -eq 0 ]; then
    echo "Skipping ${compose_file} (all services at scale 0)"
    return
  fi

  echo "Removing ${compose_file} containers..."
  docker compose -f "${compose_file}" rm -sf "${services[@]}"

  echo "Recreating ${compose_file}..."
  docker compose -f "${compose_file}" up -d "${scale_args[@]}"
}

echo "Restarting on github-runner:${RUNNER_VERSION}"

if [ -n "${TARGET}" ]; then
  if ! resolved="$(resolve_target "${TARGET}")"; then
    echo "Error: no service matching '${TARGET}' in docker-compose.*.yml"
    list_available
    exit 1
  fi
  read -r compose_file resolved_service <<<"${resolved}"
  restart_compose "${compose_file}" "${resolved_service}"
  echo "Done. Recreated ${resolved_service}."
  exit 0
fi

for compose_file in "${compose_files[@]}"; do
  mapfile -t services < <(docker compose -f "${compose_file}" config --services)
  restart_compose "${compose_file}" "${services[@]}"
done

echo "Done. All runner containers were deleted and recreated."
