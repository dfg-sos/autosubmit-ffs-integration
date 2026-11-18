#!/bin/bash
# One-time setup, everything inside this repository (nothing in ~/.autosubmitrc or ~/autosubmit):
#   envs/autosubmit  Autosubmit 4.1.17.2 (requires Python < 3.13)
#   envs/toy         Python for the toy workflow (numpy, netCDF4, xarray)
#   autosubmit/      Autosubmit configuration (.autosubmitrc), database and experiments
# The File Format Service itself runs as a container, see scripts/start-ffs.sh.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
cd "$HERE"

uv venv -q --allow-existing -p 3.12 envs/autosubmit
VIRTUAL_ENV=envs/autosubmit uv pip install -q "autosubmit==4.1.17.2"

uv venv -q --allow-existing -p 3.12 envs/toy
VIRTUAL_ENV=envs/toy uv pip install -q numpy netCDF4 xarray

R=$HERE/autosubmit/experiments
mkdir -p "$R"/{logs,structures,historic,historiclog,stats}
cat > autosubmit/.autosubmitrc <<EOF
[database]
path = $R
filename = autosubmit.db
backend = sqlite

[local]
path = $R

[globallogs]
path = $R/logs

[structures]
path = $R/structures

[historicdb]
path = $R/historic

[historiclog]
path = $R/historiclog

[defaultstats]
path = $R/stats
EOF
[ -f "$R/autosubmit.db" ] || "$HERE/scripts/as.sh" install
echo "Setup done. Next: scripts/start-ffs.sh, then scripts/run-scenario.sh none fail"
