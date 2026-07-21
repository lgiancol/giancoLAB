#!/bin/bash

set -e

if [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: GITHUB_TOKEN environment variable is required"
  exit 1
fi

if [ -z "$GITHUB_REPOSITORY" ] && [ -z "$GITHUB_ORG" ]; then
  echo "Error: Either the GITHUB_REPOSITORY or the GITHUB_ORG must be set"
  exit 1
fi

RUNNER_NAME=${RUNNER_NAME:-$(hostname)}

# Determine registration URL and token URL
if [ -n "$GITHUB_REPOSITORY" ]; then
  # Repository runner
  REGISTRATION_URL="https://github.com/${GITHUB_REPOSITORY}"
  TOKEN_URL="https://api.github.com/repos/${GITHUB_REPOSITORY}/actions/runners/registration-token"
else
  # Organization runner
  REGISTRATION_URL="https://github.com/${GITHUB_ORG}"
  TOKEN_URL="https://api.github.com/orgs/${GITHUB_ORG}/actions/runners/registration-token"
fi

# Get Registration token
echo "Obtaining registration token..."

RUNNER_TOKEN=$(curl -sX POST -H "Accept: application/vnd.github+json" -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "X-GitHub-Api-Version: 2022-11-28" "${TOKEN_URL}" | jq .token --raw-output)

if [ -z "$RUNNER_TOKEN" ] || [ "$RUNNER_TOKEN" == "null" ]; then
  echo "Error: Failed to get registration token"
  exit 1
fi

# Configure the runner
echo "Configuring runner..."
./config.sh \
  --url "${REGISTRATION_URL}" \
  --token "${RUNNER_TOKEN}" \
  --name "${RUNNER_NAME}" \
  --labels "${RUNNER_LABELS:-docker}" \
  --work "_work" \
  --unattended \
  --replace

cleanup() {
  echo "Removing runner..."
  ./config.sh remove --token "${RUNNER_TOKEN}"
}

trap cleanup EXIT

echo "Starting runner..."
./run.sh
