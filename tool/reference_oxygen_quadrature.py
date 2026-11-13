"""Independent numerical Baker integrals for optional reference capture only."""
import mpmath as mp

# Baker, Oxygen Toxicity Calculations, pp8–9. This independent reference
# numerically integrates rates; the product uses analytic band integrals.
BANDS = [('.5', '.6', -1800, 1800), ('.6', '.7', -1500, 1620),
         ('.7', '.8', -1200, 1410), ('.8', '.9', -900, 1170),
         ('.9', '1.1', -600, 900), ('1.1', '1.5', -300, 570),
         ('1.5', '1.6', -750, 1245)]


def dose(start, end, duration, gas, sp=None, *, surface_bar=1.01325):
    t = mp.mpf(str(duration))
    a, b = [mp.mpf(str(surface_bar)) + mp.mpf(str(d)) / 10 for d in [start, end]]
    if sp is None:
        a, b = a * mp.mpf(str(gas[0])), b * mp.mpf(str(gas[0]))
    cap = mp.mpf(str(sp)) if sp is not None else mp.inf
    ata = mp.mpf('1.01325')
    def p(u):
        return min(cap, a + (b-a) * u / t) / ata
    assert max(p(0), p(t)) <= mp.mpf('1.6')
    def cns(u):
        oxygen = p(u)
        if oxygen <= mp.mpf('.5'):
            return mp.mpf(0)
        for lo, hi, slope, intercept in BANDS:
            if mp.mpf(lo) < oxygen <= mp.mpf(hi):
                return 1 / (slope * oxygen + intercept)
        raise ValueError(oxygen)
    cuts = [mp.mpf(0), t]
    if a != b:
        for value in [mp.mpf(v)*ata for band in BANDS for v in band[:2]] + [cap]:
            u = t * (value-a) / (b-a)
            if 0 < u < t:
                cuts.append(u)
    cuts = sorted(set(cuts))
    return [mp.quad(cns, cuts), mp.quad(lambda u: max(mp.mpf(0), 2*p(u)-1)**(mp.mpf(5)/6), cuts)]


