"""External VPM orchestration for entered ascents followed by a deeper level.

Uses the pinned source's full critical-volume search. Only its final physical
pass is clipped at the entered target. No product implementation is imported.
"""
import copy
import math
import reference_vpm_schedule as base
from reference_vpm_state import snapshot

class _ReachedTarget(Exception):
    pass


def run_multilevel(inp, levels, setpoints, intermediate_summary):
    constructor = base.module.DiveState
    timeline = []
    holder = {}

    def factory(*args, **kwargs):
        state = constructor(*args, **kwargs)
        holder['state'] = state
        ctx = dict(actual=False, in_cv=False, target=None, depth=0., maximum_first=0., actual_gradient=[0.]*16)
        holder['context'] = ctx
        original_gradient = state.calc_max_actual_gradient
        def actual_gradient(depth):
            original_gradient(depth)
            # Upstream resets this array at the start of its single final
            # ascent. Partial ascents belong to the same dive, so their actual
            # supersaturation history must survive the next source search.
            ctx['actual_gradient'] = [max(a,b) for a,b in zip(ctx['actual_gradient'],state.Max_Actual_Gradient)]
            state.Max_Actual_Gradient = list(ctx['actual_gradient'])
        state.calc_max_actual_gradient = actual_gradient
        original_profile = state.profile_code_loop
        original_decision = state.critical_volume_decision_tree
        original_movement = state.gas_loadings_ascent_descent
        original_cv = state.critical_volume_loop
        def critical_volume():
            ctx['in_cv'] = True
            try:
                return original_cv()
            finally:
                ctx['in_cv'] = False
        state.critical_volume_loop = critical_volume
        original_boyle = state.boyles_law_compensation
        def boyle(first, stop, step):
            ctx['maximum_first'] = max(ctx['maximum_first'],first)
            return original_boyle(first,stop,step)
        state.boyles_law_compensation = boyle
        out = state.output_object

        def capture(kind, end, gas):
            if not state.Segment_Time:
                return
            timeline.append(dict(kind=kind, start_depth_m=ctx['depth'], end_depth_m=end,
                duration_min=state.Segment_Time,end_min=state.Run_Time,gas_index=gas-1,
                tissues=dict(nitrogenBar=[v*.1 for v in state.Nitrogen_Pressure],heliumBar=[v*.1 for v in state.Helium_Pressure]),bubble=snapshot(state)))
            ctx['depth'] = end

        old_profile_move = out.add_dive_profile_entry_descent
        def profile_move(number, duration, runtime, gas, word, start, end, rate):
            capture('levelTravel',end,gas)
            return old_profile_move(number,duration,runtime,gas,word,start,end,rate)
        out.add_dive_profile_entry_descent = profile_move
        old_hold = out.add_dive_profile_entry_ascent
        def hold(number,duration,runtime,gas,depth):
            capture('levelHold',depth,gas)
            return old_hold(number,duration,runtime,gas,depth)
        out.add_dive_profile_entry_ascent = hold
        old_ascent = out.add_decompression_profile_ascent
        def ascent(number,duration,runtime,gas,end,rate):
            capture('ascent',end,gas)
            old_ascent(number,duration,runtime,gas,end,rate)
            if ctx['target'] is not None and end <= ctx['target']:
                raise _ReachedTarget()
        out.add_decompression_profile_ascent = ascent
        old_stop = out.add_decompression_profile_constant
        def stop(number,duration,runtime,gas,display_depth,display_time):
            capture('decompression',state.Deco_Stop_Depth,gas)
            return old_stop(number,duration,runtime,gas,display_depth,display_time)
        out.add_decompression_profile_constant = stop

        def decision():
            ctx['actual'] = True
            try:
                return original_decision()
            finally:
                ctx['actual'] = False
        state.critical_volume_decision_tree = decision

        def movement(start,end,rate):
            # The source's NDL exit is also a final physical pass: it restores
            # the full ascent-start state and goes directly to zero inside CV.
            ndl = ctx['in_cv'] and end == 0 and start == state.Depth_Change[0] and state.Run_Time == state.Run_Time_Start_of_Ascent
            if (ctx['actual'] or ndl) and ctx['target'] is not None and end < ctx['target']:
                end = ctx['target']
                state.Deco_Stop_Depth = end
            return original_movement(start,end,rate)
        state.gas_loadings_ascent_descent = movement

        def profile(dive):
            previous = 0.
            for level in levels:
                depth, duration, move_gas, hold_gas = level
                if depth < previous:
                    ctx['target'] = depth
                    summary = copy.deepcopy(intermediate_summary)
                    summary[0]['starting_depth'] = previous
                    partial = dict(profile_codes=[dict(profile_code=99,number_of_ascent_parameter_changes=len(summary),ascent_summary=summary)])
                    try:
                        state.decompression_loop(partial)
                    except _ReachedTarget:
                        assert abs(ctx['depth']-depth) < 1e-10, 'Partial ascent ended outside its target.'
                    else:
                        raise AssertionError('Partial physical ascent did not reach target.')
                    ctx['target'] = None
                    end_time = math.ceil(state.Run_Time) + duration
                    original_profile(dict(profile_codes=[dict(profile_code=2,depth=depth,run_time_at_end_of_segment=end_time,gasmix=hold_gas)]))
                else:
                    end_time = state.Run_Time + duration
                    original_profile(dict(profile_codes=[
                        dict(profile_code=1,starting_depth=previous,ending_depth=depth,rate=10,gasmix=move_gas),
                        dict(profile_code=2,depth=depth,run_time_at_end_of_segment=end_time,gasmix=hold_gas)]))
                previous = depth
        state.profile_code_loop = profile
        return state

    base.module.DiveState = factory
    try:
        final = base.run_reference(inp,sea_bar=1.01325,ccr_setpoints_bar=setpoints)[-1]
    finally:
        base.module.DiveState = constructor
    # Published surface state includes the same independent SI0 excitation
    # finalization already used by the canonical VPM reference adapter. Preserve
    # raw source output separately; the final segment and finalState share it.
    raw_surface = copy.deepcopy(timeline[-1]['bubble'])
    timeline[-1]['bubble'] = copy.deepcopy(final['expected_bubble'])
    return dict(initial=final['initial'],expected_timeline=timeline,expected_bubble=final['expected_bubble'],raw_surface_bubble=raw_surface,maximum_first_stop_metres=holder['context']['maximum_first'])
