#!/bin/bash
# FRER_AoI Letter scenario on DNT (github.com/EricssonResearch/dnt)
# Topology mirrors Fig. 1 of the manuscript:
#
#   talker ──head── nxp1 (SGF) ══branch A══ nxp2 (SRF+POF) ──tail── listener
#                              ══branch B══
#
# Unit mapping: 1 model time unit = 10 ms  =>  T = 10 ms (100 pkt/s)
#   head/tail:  Dh = Dt = 1     -> netem delay 10ms, no loss
#   branch A :  Dprop=1, W~Exp(2),  pA=0.80 -> delay (10+5)ms  sigma 10ms expo, loss 20%
#   branch B :  Dprop=3, W~Exp(0.4),pB=0.90 -> delay (30+25)ms sigma 50ms expo, loss 10%
# (mean of Exp(beta) = 1/beta units = 5 ms and 25 ms; sigma = 2*mean, see gen_expo_dist.py)
#
# Run as root:  source env_frer_aoi.sh ; setup
set -e
export PATH=$PATH:/sbin:/usr/sbin

setup() {
  # exponential netem table -- must land in the dir tc actually searches
  # (Debian/Ubuntu: /usr/lib/x86_64-linux-gnu/tc; others: /usr/lib/tc).
  # Detect via a stock table; TC_LIB_DIR env var overrides for both us and tc.
  tclib="${TC_LIB_DIR:-$(dirname "$(find /usr/lib -name normal.dist 2>/dev/null | head -1)" 2>/dev/null)}"
  [ -d "$tclib" ] || tclib=/usr/lib/tc
  python3 "$(dirname "${BASH_SOURCE[0]}")/gen_expo_dist.py" "$tclib/expo.dist"

  for ns in talker listener nxp1 nxp2; do ip netns add $ns 2>/dev/null || true; done

  ip link add eth0 netns talker   type veth peer uni  netns nxp1     # head
  ip link add brA  netns nxp1     type veth peer brA  netns nxp2     # branch A
  ip link add brB  netns nxp1     type veth peer brB  netns nxp2     # branch B
  ip link add uni  netns nxp2     type veth peer eth0 netns listener # tail

  for ns in talker listener nxp1 nxp2; do
    ip netns exec $ns ip link set lo up
    for d in $(ip netns exec $ns ls /sys/class/net | grep -v lo); do
      ip netns exec $ns ip link set $d up
      ip netns exec $ns ethtool -K $d rx off tx off rxvlan off txvlan off 2>/dev/null || true
    done
  done

  # ---- impairments (egress qdiscs on the nxp1 side, head on talker side) ----
  # head: Dh = 10 ms, lossless
  netem_warn=0
  ip netns exec talker tc qdisc replace dev eth0 root netem delay 10ms limit 10000 || netem_warn=1
  # branch A: L_A = 10ms + Exp(mean 5ms), loss 20%
  ip netns exec nxp1 tc qdisc replace dev brA root netem \
      delay 15ms 10ms distribution expo loss random 20% limit 10000 || netem_warn=1
  # branch B: L_B = 30ms + Exp(mean 25ms), loss 10%
  ip netns exec nxp1 tc qdisc replace dev brB root netem \
      delay 55ms 50ms distribution expo loss random 10% limit 10000 || netem_warn=1
  # tail: Dt = 10 ms, lossless
  ip netns exec nxp2 tc qdisc replace dev uni root netem delay 10ms limit 10000 || netem_warn=1

  [ "$netem_warn" = 1 ] && echo "WARNING: netem unavailable (container?); impairments NOT applied"
  echo "namespaces up. start DNT:"
  echo "  ip netns exec nxp1 dnt nxp1.ini &"
  echo "  ip netns exec nxp2 dnt nxp2.ini &   # edit MaxDelay/HistoryLength per sweep point"
}

teardown() { for ns in talker listener nxp1 nxp2; do ip netns del $ns 2>/dev/null || true; done; }