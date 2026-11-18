#!/bin/bash
# Toy post-processing: time mean of every data variable of a chunk.
set -euo pipefail
OUT=%TOY.DATA_DIR%/%SDATE%/%MEMBER%
%TOY.PYTHON% - "$OUT/sim_%CHUNK%.nc" "$OUT/post_%CHUNK%.nc" <<'EOF'
import sys
import xarray as xr

src, dst = sys.argv[1:3]
with xr.open_dataset(src) as ds:
    ds.mean("time", keep_attrs=True).to_netcdf(dst)
print(f"POST wrote {dst} with variables {list(xr.open_dataset(dst).data_vars)}")
EOF
