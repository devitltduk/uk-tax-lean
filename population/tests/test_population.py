"""Tests of the synthetic population layer (not proved; the engine is).

Needs the engine: `lake build uktax` first. Run with
    uv run --project population python -m unittest discover -s population/tests
"""

from __future__ import annotations

import pathlib
import sys
import unittest

import numpy as np

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
import model  # noqa: E402

HAVE_ENGINE = model.DEFAULT_BINARY.exists()
N = 6_000


@unittest.skipUnless(HAVE_ENGINE, "build the engine first: lake build uktax")
class PopulationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pop = model.build(N, seed=7)

    def test_calibration_meets_every_published_target(self):
        # Catches a target the units cannot reach (an indicator that disagrees
        # with its target, contradictory targets) and a solver that stops early.
        target = np.array([t[1] for t in self.pop.targets])
        rel = np.abs(self.pop.fitted - target) / target
        worst = int(np.argmax(rel))
        self.assertLess(rel[worst], 1e-4, self.pop.targets[worst][0])
        # The fitted totals are the units' own: recount two of them directly.
        w = self.pop.weights
        uc = sum(wi for wi, u in zip(w, self.pop.units) if u.out["uc"] > 0)
        self.assertAlmostEqual(uc / 6_743_000, 1.0, places=4)
        scot_adults = sum(wi * len(u.adults) for wi, u in zip(w, self.pop.units) if u.country == "scotland")
        self.assertAlmostEqual(scot_adults / 4_667_501, 1.0, places=4)

    def test_same_seed_same_population(self):
        # Catches hidden randomness (unseeded draws, set or dict order) that
        # would make published figures unreproducible.
        again = model.build(N, seed=7)
        self.assertTrue(np.array_equal(self.pop.weights, again.weights))
        self.assertEqual([u.out["net"] for u in self.pop.units], [u.out["net"] for u in again.units])
        other = model.build(N, seed=8)
        self.assertFalse(np.array_equal(self.pop.weights, other.weights))

    def test_personal_allowance_plus_1000(self):
        # Worked by hand: £1,000 more allowance saves a basic rate taxpayer
        # £200 and a higher rate one £400 (at most £480 at the Scottish top
        # rate); with ~40m taxpayers that is roughly £8bn to £10bn, and nobody
        # loses (Universal Credit takes back only part of a gain). HMRC's ready
        # reckoner: £8.1bn (2026-27) to £10.5bn (2027-28). Catches reforms not
        # reaching the engine, a sign error in the cost, or a wrong weighting.
        r = model.reform(self.pop, {"personal_allowance_pence": 1_357_000})
        self.assertGreater(r["cost"], 6e9)
        self.assertLess(r["cost"], 12e9)
        self.assertEqual(r["losers"], 0.0)
        self.assertGreater(r["winners"], 25e6)
        # Most single basic rate taxpayers gain exactly £200 (20 % of £1,000).
        w = self.pop.weights
        singles = [(wi, d) for wi, d, u in zip(w, r["delta"], self.pop.units)
                   if len(u.adults) == 1 and u.out["tax"] > 0]
        share_200 = sum(wi for wi, d in singles if abs(d - 200) < 0.005) / sum(wi for wi, _ in singles)
        self.assertGreater(share_200, 0.5)
        # Nobody gains more than £750 an adult: £1,000 at the top 48 % rate
        # plus, at most, dividends moving from 35.75 % to 10.75 % or the
        # savings allowance rising £500 when they leave the higher rate band.
        max_gain = max(d / len(u.adults) for d, u in zip(r["delta"], self.pop.units))
        self.assertLessEqual(max_gain, 750.0)

    def test_basic_rate_up_one_point_raises_money(self):
        # Direction and size by hand: 1p on ~£700bn of basic rate income is
        # about £7bn (HMRC ready reckoner £6.9bn to £8.25bn); nobody gains.
        r = model.reform(self.pop, {"basic_rate_bp": 2_100})
        self.assertLess(r["cost"], -5e9)
        self.assertGreater(r["cost"], -10e9)
        self.assertEqual(r["winners"], 0.0)


class BandSamplerTest(unittest.TestCase):
    def test_draws_stay_in_the_band_with_the_published_mean(self):
        # HMRC 2026-27, £50,000 to £100,000: £492,000m over 7.49m taxpayers.
        # Catches a bisection that runs the wrong way (mean at the wrong end).
        mean = 492_000e6 / 7.49e6
        draw = model.band_sampler(50_000, 100_000, mean)
        xs = [draw((i + 0.5) / 20_000) for i in range(20_000)]
        self.assertGreaterEqual(min(xs), 50_000)
        self.assertLess(max(xs), 100_000)
        self.assertAlmostEqual(sum(xs) / len(xs) / mean, 1.0, places=3)

    def test_open_top_band_has_the_published_mean(self):
        # £2,000,000 and over: £59,200m over 11,000 taxpayers, £5.38m each.
        # A Pareto tail with that mean has alpha = 5.3818 / 3.3818 = 1.5914
        # (worked by hand), so its median is £2m x 2^(1/1.5914) = £3,091,000.
        draw = model.band_sampler(2_000_000, None, 59_200e6 / 11_000)
        self.assertAlmostEqual(draw(0.5) / 3_091_000, 1.0, places=3)

if __name__ == "__main__":
    unittest.main()
