#!/bin/bash
# Run one operating point: ./run_point.sh <D_ms> <H> <N>
# Rewrites nxp2.ini, (re)starts DNT instances, drives talker/listener.
D=${1:-43}; H=${2:-5}; N=${3:-400000}
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
ip netns exec talker python3 talker.py $N
wait $LPID
cat "result_D${D}.txt"