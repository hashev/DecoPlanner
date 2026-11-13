"""Optional pinned independent VPM execution adapter.
Never imports or executes the product. Original oracle stays byte-identical.
"""
import copy
import hashlib
import importlib.util
import json
import subprocess
from pathlib import Path
import mpmath as mp
from reference_vpm_state import snapshot

ROOT = Path(__file__).resolve().parents[1]
REF = ROOT / 'local/oracles/vpmb'
FIX = ROOT / 'packages/deco_core/test/fixtures'
PIN = 'bec938d84742e42dd43b574beec49ac26f6863ac'
assert subprocess.check_output(['git', '-C', str(REF), 'rev-parse', 'HEAD'], text=True).strip() == PIN
source = (REF / 'vpmb.py').read_text()
old = 'round((last_run_time / self.Minimum_Deco_Stop_Time) + 0.5)'
assert source.count(old) == 1
normalized = source.replace(old, 'round((last_run_time / self.Minimum_Deco_Stop_Time) + 0.501)')
spec = importlib.util.spec_from_file_location('vpmb_schedule_reference', REF / 'vpmb.py')
module = importlib.util.module_from_spec(spec)
exec(compile(normalized, str(REF / 'vpmb.py'), 'exec'), module.__dict__)
mp.mp.dps = 70

def root(a, b, c, lo, hi):
    if lo == hi:
        return lo
    a, b, c, lo, hi = [mp.mpf(str(v)) for v in (a, b, c, lo, hi)]
    scale = hi
    norm = max(abs(a * scale**3), abs(b * scale**2), abs(c))
    return float(scale * mp.findroot(lambda x: (a*(scale*x)**3-b*(scale*x)**2-c)/norm,
        (lo/scale, 1), solver='bisect', tol=mp.mpf('1e-50'), maxsteps=250))
module.radius_root_finder = root


def run_reference(inp, *, sea_bar=None, swapped=False, ccr_setpoints_bar=None):
    state = module.DiveState(json_input=copy.deepcopy(inp))
    original_initialize = state.initialize_data
    def initialize():
        original_initialize()
        if sea_bar is not None:
            state.Barometric_Pressure = sea_bar * 10
            state.Nitrogen_Pressure = [(state.Barometric_Pressure-state.Water_Vapor_Pressure)*.79]*16
    state.initialize_data = initialize
    if swapped:
        for method in ['calc_initial_allowable_gradient', 'critical_volume']:
            original = getattr(state, method)
            def swapped_gradients(*args, _original=original):
                result = _original(*args)
                state.Allowable_Gradient_N2, state.Allowable_Gradient_He = state.Allowable_Gradient_He, state.Allowable_Gradient_N2
                return result
            setattr(state, method, swapped_gradients)
    maximum = [0.0]
    iterations = [0]
    original_boyle = state.boyles_law_compensation
    def boyle(first, stop, step):
        maximum[0] = max(maximum[0], first)
        return original_boyle(maximum[0], stop, step)
    state.boyles_law_compensation = boyle
    original_ceiling = state.calc_ascent_ceiling
    def ceiling():
        iterations[0] += 1
        return original_ceiling()
    state.calc_ascent_ceiling = ceiling
    original_zone = state.calc_start_of_deco_zone
    def zone(start, rate):
        # Refine only source root precision, using its independent Schreiner equations.
        original_zone(start, rate)
        depths = []
        ambient = mp.mpf(str(start + state.Barometric_Pressure))
        r = mp.mpf(str(rate))
        mix = state.Mix_Number - 1
        for i in range(16):
            def tension(t):
                total = mp.mpf(str(state.Constant_Pressure_Other_Gases))
                for values, fractions, constants in [(state.Helium_Pressure, state.Fraction_Helium, state.Helium_Time_Constant),
                                                     (state.Nitrogen_Pressure, state.Fraction_Nitrogen, state.Nitrogen_Time_Constant)]:
                    old = mp.mpf(str(values[i])); k = mp.mpf(str(constants[i])); f = mp.mpf(str(fractions[mix]))
                    p = (ambient - mp.mpf(str(state.Water_Vapor_Pressure))) * f
                    q = r * f
                    total += p + q*(t-1/k) - (p-old-q/k)*mp.exp(-k*t)
                return total - (ambient+r*t)
            t = mp.findroot(tension, (0, -ambient/r), solver='bisect', tol=mp.mpf('1e-50'), maxsteps=250)
            depths.append(float(mp.mpf(str(start)) + r*t))
        state.Depth_Start_of_Deco_Zone = max(depths)
    state.calc_start_of_deco_zone = zone
    per_dive_setpoints = ccr_setpoints_bar is not None and isinstance(ccr_setpoints_bar[0], list)
    active_setpoints = [ccr_setpoints_bar[0] if per_dive_setpoints else ccr_setpoints_bar]
    profile_index = [0]
    if ccr_setpoints_bar is not None:
        # Extend the OC oracle's inspired-pressure preparation only. For constant
        # SP, (ambient-vapour-SP)*inert_ratio is exactly its linear OC equation
        # with shifted vapour and normalized inert fractions. The source VPM
        # physics/search stays external. Do not use this adapter for segments
        # crossing dry ambient=SP: that requires a clipped propagation adapter.
        nested = [False]
        for method in ['gas_loadings_ascent_descent', 'gas_loadings_constant_depth',
                       'calc_crushing_pressure', 'onset_of_impermeability',
                       'calc_start_of_deco_zone', 'projected_ascent', 'decompression_stop']:
            original = getattr(state, method)
            def ccr_inspiration(*args, _original=original, _method=method):
                index = state.Mix_Number - 1
                sp = active_setpoints[0][index]
                if nested[0] or sp is None:
                    return _original(*args)
                vapour = state.Water_Vapor_Pressure
                if _method == 'gas_loadings_ascent_descent':
                    assert min(args[:2]) + state.Barometric_Pressure >= vapour + sp*10, 'CCR adapter does not cover dry-pressure clipping'
                elif _method in ['gas_loadings_constant_depth', 'decompression_stop']:
                    assert args[0] + state.Barometric_Pressure >= vapour + sp*10, 'CCR adapter does not cover dry-pressure clipping'
                n2, he = state.Fraction_Nitrogen, state.Fraction_Helium
                total = n2[index] + he[index]
                assert total > 0
                state.Fraction_Nitrogen = list(n2)
                state.Fraction_Helium = list(he)
                state.Fraction_Nitrogen[index] /= total
                state.Fraction_Helium[index] /= total
                state.Water_Vapor_Pressure += sp * 10
                nested[0] = True
                try:
                    return _original(*args)
                finally:
                    nested[0] = False
                    state.Water_Vapor_Pressure = vapour
                    state.Fraction_Nitrogen, state.Fraction_Helium = n2, he
            setattr(state, method, ccr_inspiration)
    segments = []
    def record(kind, duration, runtime, mix, end_depth):
        segments.append(dict(kind=kind, duration_min=duration, end_min=runtime,
            end_depth_m=end_depth, gas_index=mix-1,
            tissues=dict(nitrogenBar=[v*.1 for v in state.Nitrogen_Pressure],
                         heliumBar=[v*.1 for v in state.Helium_Pressure])))
    out = state.output_object
    profile_segments = []
    if ccr_setpoints_bar is not None:
        for method in ['add_dive_profile_entry_descent', 'add_dive_profile_entry_ascent']:
            original = getattr(out, method)
            def profile_record(*args, _original=original):
                profile_segments.append(dict(end_min=state.Run_Time,
                    tissues=dict(nitrogenBar=[v*.1 for v in state.Nitrogen_Pressure],
                                 heliumBar=[v*.1 for v in state.Helium_Pressure]),
                    bubble=snapshot(state)))
                return _original(*args)
            setattr(out, method, profile_record)
    old_ascent = out.add_decompression_profile_ascent
    def ascent(number, duration, runtime, mix, end_depth, rate):
        record('ascent', duration, runtime, mix, end_depth)
        return old_ascent(number, duration, runtime, mix, end_depth, rate)
    out.add_decompression_profile_ascent = ascent
    old_stop = out.add_decompression_profile_constant
    def stop(number, duration, runtime, mix, depth, display):
        record('decompression', duration, runtime, mix, depth)
        return old_stop(number, duration, runtime, mix, depth, display)
    out.add_decompression_profile_constant = stop
    dives = []
    initial = {}
    original_profile = state.profile_code_loop
    def profile(dive):
        if per_dive_setpoints:
            active_setpoints[0] = ccr_setpoints_bar[profile_index[0]]
            profile_index[0] += 1
        initial.clear()
        initial.update(tissues=dict(nitrogenBar=[v*.1 for v in state.Nitrogen_Pressure],
                                    heliumBar=[v*.1 for v in state.Helium_Pressure]),
            pressure_bar=state.Barometric_Pressure*.1,
            radius_n2_m=list(state.Adjusted_Critical_Radius_N2),
            radius_he_m=list(state.Adjusted_Critical_Radius_He))
        return original_profile(dive)
    state.profile_code_loop = profile
    original_decompression = state.decompression_loop
    def decompression(dive):
        maximum[0] = 0.0
        iterations[0] = 0
        start_index = len(segments)
        result = original_decompression(dive)
        # Source's NDL exit omits this even when earlier trials had stops.
        # Applying the final surface maximum is idempotent for normal schedules;
        # maximum trial first-stop depth is not evidence of an actual stop.
        state.calc_max_actual_gradient(0)
        finalized = copy.deepcopy(state)
        finalized.vpm_repetitive_algorithm(0)
        bubble = snapshot(finalized)
        bubble.update(maximumFirstStopMetres=maximum[0], criticalVolumeIterations=iterations[0])
        record = dict(initial=copy.deepcopy(initial), expected_segments=segments[start_index:], expected_bubble=bubble)
        if ccr_setpoints_bar is not None:
            record['expected_profile_segments'] = copy.deepcopy(profile_segments)
            profile_segments.clear()
        dives.append(record)
        return result
    state.decompression_loop = decompression
    state.main()
    return dives
