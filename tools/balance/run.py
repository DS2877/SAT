"""Progression simulation with the launch balance (see docs/LAUNCH_PLAN.md).
Run from the repo root: python3 tools/balance/run.py
Keep the numbers below in sync with GameConfig when rebalancing."""
import os, random, statistics, sys
sys.path.insert(0, os.path.dirname(__file__))
from sim import sim

cfg = dict(
    tiers=[(5, 0), (10, 25000), (20, 750000), (40, 25000000), (60, 500000000)],
    benches=[(0, 5, 0), (15000, 12, 0), (1500000, 30, 1), (30000000, 75, 2), (600000000, 180, 4)],
    trainmul=1.6,
    ascmul=lambda l: [1, 1.5, 2, 2.5, 3][l] if l < 5 else 3 + 0.5 * (l - 4),
    req=lambda l: 30000 * 2.5 ** l,
    cost=lambda n: [10e6, 100e6, 1e9, 5e9][n - 1] if n <= 4 else 5e9 * 5 ** (n - 4),
    reset_vault=True,
    keep=1,
)
for share, picks, label in [(0.35, 4, "active player"), (0.2, 2, "busy server")]:
    random.seed(2)
    milestones = {}
    for _ in range(40):
        events, _, _ = sim(cfg, hours=10, share=share, picks=picks)
        for k, v in events.items():
            milestones.setdefault(k, []).append(v)
    print("==", label)
    for k in sorted(milestones, key=lambda k: statistics.median(milestones[k])):
        print(f"  {k:10} median {statistics.median(milestones[k]):6.0f} min ({len(milestones[k])}/40 runs)")
