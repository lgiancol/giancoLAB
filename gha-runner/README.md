## Setup Instructions

1. You will need org-specific env files (`.env.oneiron`, `.env.clubhouse`, etc.) with `GITHUB_TOKEN` and `GITHUB_ORG` set. Your `GITHUB_TOKEN` needs read/write access to self-hosted runners in that organization.
2. Build (or upgrade) the runner image and recreate all fleets with one command:

   ```bash
   ./update.sh 2.335.1
   ```

   - Builds `github-runner:<version>`
   - Writes `RUNNER_VERSION` to the root `.env` (used by compose for the image tag)
   - Recreates each active fleet at its current scale

3. Fully delete and recreate runner containers (same image/version, same scale).
   Omit the service to restart everything, or pass a service/stem to target one fleet:

   ```bash
   ./restart.sh
   ./restart.sh oneiron
   ./restart.sh clubhouse_runner
   ```

4. Scale a fleet as needed (service name or compose stem, then count):

   ```bash
   ./scale.sh oneiron 3
   ./scale.sh clubhouse_runner 3
   ```

**NOTE**

When a container restarts, the runner may try to fetch a newer version and fail to come back up. Use `./update.sh <new-version>` to rebuild and roll everything forward. Image builds can take a long time — if a step looks stuck, wait another 10 minutes before assuming it failed.

The built image is >1GB because it is based on a full Ubuntu image.
