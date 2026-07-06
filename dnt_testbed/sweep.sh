#!/bin/bash
# Sweep the POF hold time D (ms): one run_point.sh call per (D, H*, rep).
# T = 1 ms  =>  H* = ceil(D/T) = D, capped at Hmax = 16.
# Run as root:  sudo ./sweep.sh
# Override defaults via env:  D_LIST="2 4 6" R=10 N=60000 sudo -E ./sweep.sh
cd "$(dirname "${BASH_SOURCE[0]}")"
D_LIST=${D_LIST:-"1 2 3 4 5 6 8 10 12 16"}
R=${R:-5}
N=${N:-60000}          # keep < 65536 (16-bit R-TAG seq in DNT's POF)
HMAX=16
OUT=${OUT:-sweep_results.txt}

echo "# sweep $(date -Is)  N=$N R=$R D_LIST=[$D_LIST]" >> "$OUT"
for D in $D_LIST; do
  H=$(( D < HMAX ? D : HMAX ))
  [ "$H" -lt 1 ] && H=1
  for r in $(seq 1 "$R"); do
    line=$(./run_point.sh "$D" "$H" "$N" | tail -1)
    echo "D=$D H=$H rep=$r  $line" | tee -a "$OUT"
  done
done
echo "done -> $OUT  (aggregate with: python3 aggregate_results.py $OUT)"
