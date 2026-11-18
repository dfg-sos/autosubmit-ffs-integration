#!/bin/bash
# Toy "model": writes one NetCDF file (CF conventions) per chunk.
# Fault injection (TOY.FAULT in experiment/conf/toy.yml): in chunk TOY.FAULT.CHUNK the output is
#   truncate - cut off while writing (wallclock kill, full quota, ...)
#   empty    - coordinates only, the data variable is missing
set -euo pipefail
OUT=%TOY.DATA_DIR%/%SDATE%/%MEMBER%
mkdir -p "$OUT"
%TOY.PYTHON% - "$OUT/sim_%CHUNK%.nc" %CHUNK% <<'EOF'
import sys
import numpy as np
from netCDF4 import Dataset

path, chunk = sys.argv[1], int(sys.argv[2])
with Dataset(path, "w") as ds:
    ds.Conventions = "CF-1.8"
    ds.createDimension("time", 4)
    ds.createDimension("lat", 18)
    ds.createDimension("lon", 36)
    t = ds.createVariable("time", "f8", ("time",)); t.units = "days since 2000-01-01"; t[:] = (chunk - 1) * 120 + np.arange(4) * 30
    la = ds.createVariable("lat", "f4", ("lat",)); la.units = "degrees_north"; la[:] = np.linspace(-85, 85, 18)
    lo = ds.createVariable("lon", "f4", ("lon",)); lo.units = "degrees_east"; lo[:] = np.linspace(-175, 175, 36)
    if not ("%TOY.FAULT.KIND%" == "empty" and chunk == %TOY.FAULT.CHUNK%):
        tas = ds.createVariable("tas", "f4", ("time", "lat", "lon")); tas.units = "K"; tas.standard_name = "air_temperature"
        tas[:] = 288 + np.random.default_rng(chunk).normal(0, 5, (4, 18, 36))
EOF
if [ "%TOY.FAULT.KIND%" = "truncate" ] && [ %CHUNK% -eq %TOY.FAULT.CHUNK% ]; then
  truncate -s 200 "$OUT/sim_%CHUNK%.nc"
fi
echo "SIM chunk %CHUNK% wrote $OUT/sim_%CHUNK%.nc"
