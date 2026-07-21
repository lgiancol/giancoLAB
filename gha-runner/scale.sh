#!/bin/bash
set -euo pipefail

SERVICE="${1:-}"
SCALE_TO="${2:-}"

if [ -z "${SERVICE}" ] || [ -z "${SCALE_TO}" ]; then
  echo "Usage: ./scale.sh <service> <count>"
  echo "Example: ./scale.sh oneiron_runner 3"
  echo "     or: ./scale.sh oneiron 3"
  exit 1
fi

if ! [[ "${SCALE_TO}" =~ ^[0-9]+$ ]]; then
  echo "Error: scale count must be a non-negative integer."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

shopt -s nullglob
compose_files=(docker-compose.*.yml)
if [ ${#compose_files[@]} -eq 0 ]; then
  echo "Error: no docker-compose.*.yml files found"
  exit 1
fi

compose_file=""
resolved_service=""

for file in "${compose_files[@]}"; do
  stem="${file#docker-compose.}"
  stem="${stem%.yml}"

  mapfile -t services < <(docker compose -f "${file}" config --services)
  for svc in "${services[@]}"; do
    if [ "${svc}" = "${SERVICE}" ] || [ "${stem}" = "${SERVICE}" ]; then
      compose_file="${file}"
      resolved_service="${svc}"
      break 2
    fi
  done
done

if [ -z "${compose_file}" ]; then
  echo "Error: no service matching '${SERVICE}' in docker-compose.*.yml"
  echo "Available:"
  for file in "${compose_files[@]}"; do
    stem="${file#docker-compose.}"
    stem="${stem%.yml}"
    mapfile -t services < <(docker compose -f "${file}" config --services)
    for svc in "${services[@]}"; do
      echo "  ${stem} / ${svc}  (${file})"
    done
  done
  exit 1
fi

echo "Scaling ${resolved_service} (${compose_file}) to ${SCALE_TO}..."
docker compose -f "${compose_file}" up -d --scale "${resolved_service}=${SCALE_TO}"
echo "Done."
