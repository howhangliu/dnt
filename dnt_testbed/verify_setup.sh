#!/bin/bash
# Sanity checks for the FRER-AoI testbed. Run as root, ideally right after a
# fresh setup + one run_point.sh run (counters accumulate across runs):
#   sudo ./verify_setup.sh
#
# What to expect (single run of N frames, e.g. N=60000):
#   1. qdiscs:  talker/eth0 netem delay 10ms; nxp1/brA netem 15ms+-10ms expo loss 20%;
#               nxp1/brB netem 55ms+-50ms expo loss 10%; nxp2/uni netem delay 10ms.
#               tc -s "dropped" on brA ~ 0.20*N, on brB ~ 0.10*N  -> loss active
#   2. replication:  nxp1 brA TX + drops ~ N  AND  brB TX + drops ~ N  (two copies made)
#   3. elimination:  nxp2 uni TX ~ N*(1 - 0.2*0.1) ~ 0.98*N  (duplicates removed,
#                    only both-copies-lost packets missing)
#   4. ordering:  listener prints outOfOrder=0 (POF holds packets to restore order);
#                 falsify by running with D=0 (./run_point.sh 0 1 5000) -> outOfOrder>0

echo "=== 1. impairment qdiscs + drop counters ==="
for p in talker:eth0 nxp1:brA nxp1:brB nxp2:uni; do
  ns=${p%:*}; dev=${p#*:}
  echo "--- $ns / $dev"
  ip netns exec "$ns" tc -s qdisc show dev "$dev"
done

echo
echo "=== 2./3. per-interface packet counters (RX then TX blocks) ==="
echo "--- nxp1 brA (replicated copy A, TX+dropped ~ N)"
ip netns exec nxp1 ip -s link show brA
echo "--- nxp1 brB (replicated copy B, TX+dropped ~ N)"
ip netns exec nxp1 ip -s link show brB
echo "--- nxp2 uni (after elimination+POF, TX ~ 0.98*N)"
ip netns exec nxp2 ip -s link show uni
echo "--- listener eth0 (RX ~ 0.98*N)"
ip netns exec listener ip -s link show eth0
