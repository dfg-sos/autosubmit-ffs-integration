#!/usr/bin/env python3
"""Validate the files of an Autosubmit job with the SOS File Format Service.

Reads the job's FFS_INPUTS or FFS_OUTPUTS from stdin, as Autosubmit writes them
into the job script (a Python literal), e.g.

    {'SIM_OUT': {'FORMAT': 'https://dfg-sos.github.io/ontologies/eo-formats#NetCDF_CF',
                 'PATH': '/data/a000/20000101/fc0/sim_1.nc'}}

sends one request per file to the service, prints and logs each result, and
exits 1 if a check failed (FAILURE, or the service rejected the request or was
unreachable). UNCERTAIN only warns. Standard library only.
"""

import argparse
import ast
import json
import sys
import urllib.error
import urllib.request


def split_format_iri(iri):
    """Split a format IRI after its last '#' or '/' into (namespace, identifier), as the CWL runner does."""
    cut = max(iri.rfind("#"), iri.rfind("/"))
    if cut <= 0 or cut == len(iri) - 1:
        raise ValueError(f"not a format IRI: {iri!r}")
    return iri[: cut + 1], iri[cut + 1 :]


def validate(url, mode, iri, path):
    """Return (status, error messages) of the service for one file."""
    namespace, identifier = split_format_iri(iri)
    endpoint = "basic" if mode == "basic" else f"{mode}/local"
    body = json.dumps({"file_path": path, "ontology_namespace": namespace, "format_identifier": identifier})
    req = urllib.request.Request(f"{url}/api/v1/validate/{endpoint}", data=body.encode(),
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            result = json.load(resp)
        return result["status"], [e["message"] for e in result.get("errors", [])]
    except urllib.error.HTTPError as e:  # request rejected, e.g. unmapped format or path not shared
        return "SERVICE_ERROR", [f"HTTP {e.code}: {e.read().decode(errors='replace')[:500]}"]
    except OSError as e:  # service unreachable
        return "SERVICE_ERROR", [str(e)]


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--url", required=True, help="service base URL")
    p.add_argument("--mode", choices=["basic", "metadata", "content"], default="metadata")
    p.add_argument("--phase", choices=["pre", "post"], required=True, help="inputs (pre) or outputs (post)")
    p.add_argument("--job", required=True, help="Autosubmit job name")
    p.add_argument("--on-failure", choices=["fail", "warn"], default="fail")
    p.add_argument("--log", required=True, help="JSON lines file the results are appended to")
    args = p.parse_args()

    text = sys.stdin.read().strip()
    files = ast.literal_eval(text) if text else {}  # empty: the job declares no files
    failed = False
    for name, decl in files.items():
        status, errors = validate(args.url.rstrip("/"), args.mode, decl["FORMAT"], decl["PATH"])
        fails = status in ("FAILURE", "SERVICE_ERROR") and args.on_failure == "fail"
        failed |= fails
        out = sys.stdout if status == "SUCCESS" else sys.stderr
        print(f"[ffs] {args.job} {args.phase} {name} {decl['PATH']}: {status}", file=out)
        for message in errors:
            print(f"[ffs]   {message}", file=out)
        with open(args.log, "a") as log:
            log.write(json.dumps({"job": args.job, "phase": args.phase, "file": name, "format": decl["FORMAT"],
                                  "path": decl["PATH"], "status": status, "failed_job": fails}) + "\n")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
