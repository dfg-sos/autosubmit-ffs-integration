#!/bin/bash
# Create a new experiment from experiment/conf, inject a fault, run it and summarise.
# Usage: scripts/run-scenario.sh FAULT_KIND ON_FAILURE
#   FAULT_KIND  none | empty | truncate   (fault in chunk 2 of SIM, see project/templates/sim.sh)
#   ON_FAILURE  fail | warn               (warn = plain Autosubmit; checks are only logged)
# Requires scripts/setup.sh and a running service (scripts/start-ffs.sh).
set -uo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd); AS=$HERE/scripts/as.sh
mkdir -p "$HERE/data"
KIND=${1:?FAULT_KIND: none|empty|truncate}; ONFAIL=${2:?ON_FAILURE: fail|warn}

EXPID=$($AS expid -H local -d "FFS PoC: fault=$KIND on_failure=$ONFAIL" 2>&1 | grep -ao "Experiment [a-z0-9]\{4\} created" | awk '{print $2}')
[ -n "$EXPID" ] || { echo "autosubmit expid failed" >&2; exit 1; }

# Replace the generated default configuration by ours (one file per template, named <name>_<expid>.yml).
CONF=$HERE/autosubmit/experiments/$EXPID/conf
rm -f "$CONF"/*.yml
for f in "$HERE"/experiment/conf/*.yml; do
  sed -e "s|@EXPID@|$EXPID|g" -e "s|@REPO@|$HERE|g" "$f" > "$CONF/$(basename "$f" .yml)_$EXPID.yml"
done
sed -i "s/^\(    KIND:\) none /\1 $KIND /" "$CONF/toy_$EXPID.yml"
sed -i "s/^\(  ON_FAILURE:\) fail /\1 $ONFAIL /" "$CONF/ffs_$EXPID.yml"

$AS create "$EXPID" -np > "$HERE/data/create-$EXPID.log" 2>&1 || { echo "autosubmit create failed, see data/create-$EXPID.log" >&2; exit 1; }
$AS run "$EXPID" > "$HERE/data/run-$EXPID.log" 2>&1

echo "== $EXPID  fault=$KIND  on_failure=$ONFAIL"
echo "-- jobs (never run: not listed)"
grep -aoE "Job ${EXPID}_\S+ changed from RUNNING to (COMPLETED|FAILED)" "$HERE/data/run-$EXPID.log" | sed -e 's/changed from RUNNING to //' -e "s/Job ${EXPID}_20000101_fc0_/  /"
echo "-- format checks ($HERE/data/$EXPID/ffs_checks.jsonl)"
[ -f "$HERE/data/$EXPID/ffs_checks.jsonl" ] && python3 "$HERE/scripts/summarize_checks.py" "$HERE/data/$EXPID/ffs_checks.jsonl"
echo "-- post-processed files"
shopt -s nullglob
for f in "$HERE"/data/$EXPID/20000101/fc0/post_*.nc; do
  printf '  %s: ' "$(basename "$f")"
  "$HERE/envs/toy/bin/python" -c "import sys, xarray as xr; print('data variables', list(xr.open_dataset(sys.argv[1]).data_vars))" "$f"
done
echo "Job logs: autosubmit/experiments/$EXPID/tmp/LOG_$EXPID/"
