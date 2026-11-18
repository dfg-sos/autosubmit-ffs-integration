#!/bin/bash
################################################
# SOS File Format Service: check the job outputs
################################################
# Appended by Autosubmit to its tailer (job key EXTENDED_TAILER_PATH), so it runs
# only if the job body succeeded. The outputs are declared in FFS_OUTPUTS, passed
# to ffs_check.py on stdin as in header.sh.
# No backslashes in this file: Autosubmit would re.escape the whole script.
# Autosubmit's tailer ends with `wait`, so a failed check must exit explicitly.
%FFS.PYTHON% %PROJDIR%/ffs/ffs_check.py --phase post --job %JOBNAME% --url %FFS.URL% --mode %FFS.MODE% --on-failure %FFS.ON_FAILURE% --log %FFS.LOG% <<'FFS_DECLARATIONS' || exit 1
%CURRENT_FFS_OUTPUTS%
FFS_DECLARATIONS
