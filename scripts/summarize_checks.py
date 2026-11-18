"""Print the format checks of an experiment (data/<expid>/ffs_checks.jsonl) as a table."""

import json
import sys

for line in open(sys.argv[1]):
    r = json.loads(line)
    job = r["job"].split("_fc0_")[-1]
    name = r["path"].rsplit("/", 1)[-1]
    print(f"  {job:7} {r['phase']:4} {name:10} {r['status']:8}{'  -> job fails' if r['failed_job'] else ''}")
