#!/bin/bash
# Run one operating point: ./run_point.sh <D_ms> <H> <N>
# Rewrites nxp2.ini, (re)starts DNT instances, drives talker/listener.
D=${1:-4}; H=${2:-4}; N=${3:-60000}
# Locate the dnt binary. sudo resets PATH to a secure_path that excludes the
# project dir, so pass an explicit path. Override with: DNT=/path/to/dnt ./run_point.sh
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DNT="${DNT:-$(command -v dnt || echo "$HERE/../dnt")}"
if [ ! -x "$DNT" ]; then echo "ERROR: dnt binary not found/executable at '$DNT'" >&2; exit 1; fi
sed -i "s/MaxDelay=[0-9]*/MaxDelay=$D/; s/frerSeqRcvyHistoryLength=[0-9]*/frerSeqRcvyHistoryLength=$H/" nxp2.ini
pkill -f "dnt.*nxp[12]\.ini" 2>/dev/null; sleep 0.5
ip netns exec nxp1 "$DNT" nxp1.ini & sleep 0.5
ip netns exec nxp2 "$DNT" nxp2.ini & sleep 0.5
ip netns exec listener python3 listener.py $N > "result_D${D}.txt" &
LPID=$!
# SCHED_FIFO keeps the 1 kHz source jitter low; fall back if chrt unavailable
if ip netns exec talker chrt -f 1 true 2>/dev/null; then TK="chrt -f 80"; else TK=""; fi
ip netns exec talker $TK python3 talker.py $N
wait $LPID
cat "result_D${D}.txt"