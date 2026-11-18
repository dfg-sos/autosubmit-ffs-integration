#!/bin/bash
###############################################
# SOS File Format Service: check the job inputs
###############################################
# Appended by Autosubmit after its header (job key EXTENDED_HEADER_PATH).
# The inputs are declared per job section in FFS_INPUTS; Autosubmit writes that mapping into
# the heredoc below as a Python literal, which ffs_check.py reads from stdin. The quoted
# heredoc keeps bash from interpreting its quotes and braces.
# No backslashes in this file: Autosubmit would re.escape the whole script.
%FFS.PYTHON% %PROJDIR%/ffs/ffs_check.py --phase pre --job %JOBNAME% --url %FFS.URL% --mode %FFS.MODE% --on-failure %FFS.ON_FAILURE% --log %FFS.LOG% <<'FFS_DECLARATIONS' || exit 1
%CURRENT_FFS_INPUTS%
FFS_DECLARATIONS
