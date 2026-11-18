#!/bin/bash
# Start the SOS File Format Service (published image with the EO plugin) on 127.0.0.1:8765.
# Mounts the EO mapping of this repository and data/, where the experiments write their files,
# so that the jobs can have files validated in place (/validate/<mode>/local).
# Stop it with: docker rm -f autosubmit-ffs
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
IMAGE=${FFS_IMAGE:-ghcr.io/dfg-sos/file-format-service-eo:0.4.0}
mkdir -p "$HERE/data"
docker rm -f autosubmit-ffs >/dev/null 2>&1 || true
docker run -d --name autosubmit-ffs -p 127.0.0.1:8765:8000 \
  -v "$HERE/service/mappings:/app/mappings:ro" \
  -v "$HERE/data:/data:ro" \
  -e SOS_FFS_SHARED_DIRS="$HERE/data:/data" \
  "$IMAGE" >/dev/null
for _ in $(seq 1 60); do
  if curl -sf http://127.0.0.1:8765/health >/dev/null; then echo "File Format Service ($IMAGE) up on http://127.0.0.1:8765"; exit 0; fi
  sleep 1
done
echo "service did not become healthy, see: docker logs autosubmit-ffs" >&2
exit 1
