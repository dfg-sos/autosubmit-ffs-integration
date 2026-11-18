# Autosubmit × SOS File Format Service: proof of concept

This repository shows that the [SOS File Format Service](https://github.com/dfg-sos/file-format-service) can validate the files of an [Autosubmit](https://autosubmit.readthedocs.io/) workflow at run time. It needs no changes to Autosubmit, and none to the service. It is the Autosubmit counterpart of the [format-aware CWL runner](https://github.com/dfg-sos/file-format-aware-cwl-runner). It is a proof of concept, not a finished extension.

## How the integration works

```yaml
# experiment/conf/jobs.yml
  POST:
    EXTENDED_HEADER_PATH: ffs/header.sh   # check FFS_INPUTS before the job's script
    EXTENDED_TAILER_PATH: ffs/tailer.sh   # check FFS_OUTPUTS after it
    FFS_INPUTS:
      SIM_OUT:                            # a name for the file, used in logs
        FORMAT: "https://dfg-sos.github.io/ontologies/eo-formats#NetCDF_CF"   # the format it must have
        PATH: "%TOY.DATA_DIR%/%SDATE%/%MEMBER%/sim_%CHUNK%.nc"
    FFS_OUTPUTS:
      TIME_MEAN:
        FORMAT: "https://dfg-sos.github.io/ontologies/eo-formats#NetCDF_CF"
        PATH: "%TOY.DATA_DIR%/%SDATE%/%MEMBER%/post_%CHUNK%.nc"
```

- **Hook points:** Autosubmit 4 appends a per-job script to its job header (`EXTENDED_HEADER_PATH`) and its tailer (`EXTENDED_TAILER_PATH`). The header checks a job's inputs before its body runs. The tailer checks its outputs after a successful body. A failed check exits non-zero, so Autosubmit marks the job `FAILED` and does not start its dependants, exactly like any other job failure.
- **Declarations:** the files to check come from custom job keys, `FFS_INPUTS` and `FFS_OUTPUTS`, because Autosubmit has no notion of job files. Each names a file and gives its `PATH` and its `FORMAT`, the full IRI of a format class in any ontology the service has a mapping for. Autosubmit fills in the `%SDATE%`, `%MEMBER%` and `%CHUNK%` placeholders per job.
- **Settings:** [`experiment/conf/ffs.yml`](experiment/conf/ffs.yml) holds the service URL, the mode (`basic`/`metadata`/`content`) and `ON_FAILURE` (`fail`/`warn`).
- **Client:** [`project/ffs/ffs_check.py`](project/ffs/ffs_check.py) turns the declarations into HTTP requests to the service, logs the results, and exits non-zero if a check fails.

The toy workflow in [`experiment/conf/jobs.yml`](experiment/conf/jobs.yml) runs over three chunks. `SIM` writes one CF NetCDF file per chunk, and `POST` computes its time mean. [`project/templates/sim.sh`](project/templates/sim.sh) can inject a fault into chunk 2:

- `empty`: the data variable is missing, as when a model writes only coordinates.
- `truncate`: the file is cut to 200 bytes, as on a wallclock kill or a full quota.

## Results

Autosubmit 4.1.17.2 on the `LOCAL` platform, service in `metadata` mode:

| Fault in SIM chunk 2 | With checks (`ON_FAILURE: fail`) | Without checks (`ON_FAILURE: warn`) |
|---|---|---|
| none | all jobs complete | all jobs complete |
| `empty` | SIM.2 fails, nothing downstream runs | all jobs complete, `post_2.nc` has no data |
| `truncate` | SIM.2 fails, nothing downstream runs | POST.2 fails with an HDF error |

## Run it

Requires [uv](https://docs.astral.sh/uv/), Docker and `python3`. The service runs as the published image `ghcr.io/dfg-sos/file-format-service-eo:0.4.0` (set `FFS_IMAGE` for another). Everything the scripts create goes to gitignored directories in this repository (`envs/`, `autosubmit/`, `data/`). Autosubmit normally keeps its configuration in `~/.autosubmitrc` and its experiments in `~/autosubmit`; [`scripts/as.sh`](scripts/as.sh) points it to `autosubmit/.autosubmitrc` instead, so an existing Autosubmit setup on the machine is left alone.

```sh
scripts/setup.sh                       # venvs, Autosubmit configuration and database
scripts/start-ffs.sh                   # service container on 127.0.0.1:8765 (stop: docker rm -f autosubmit-ffs)
scripts/run-scenario.sh none fail      # new experiment, run, summary
scripts/run-scenario.sh empty fail
scripts/run-scenario.sh empty warn
scripts/run-scenario.sh truncate fail
scripts/run-scenario.sh truncate warn
scripts/as.sh <autosubmit command>     # Autosubmit with this repository's configuration, e.g. `scripts/as.sh monitor a001`
```

## Layout

```
experiment/conf/   experiment configuration templates (@EXPID@, @REPO@ are filled in by run-scenario.sh)
project/           Autosubmit project (PROJECT_TYPE: local), copied into each experiment
  ffs/             header.sh, tailer.sh and the client ffs_check.py: the integration
  templates/       sim.sh, post.sh: the toy climate jobs with fault injection
service/mappings/  EO ontology → validator mapping, mounted into the service
scripts/           setup, service start, scenario runner, autosubmit wrapper
```
