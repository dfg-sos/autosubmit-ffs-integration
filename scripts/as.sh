#!/bin/bash
# Autosubmit with this project's configuration (autosubmit/.autosubmitrc), not ~/.autosubmitrc.
HERE=$(cd "$(dirname "$0")/.." && pwd)
AUTOSUBMIT_CONFIGURATION=$HERE/autosubmit/.autosubmitrc PYTHONWARNINGS=ignore exec "$HERE/envs/autosubmit/bin/autosubmit" "$@"
