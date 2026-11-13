"""Semantic snapshot adapter for the optional pinned VPM reference only."""
def snapshot(state):
    f=1.01325/state.Units_Factor
    result={'modelVersion':'vpmb-decoplanner-parameters-v1'}
    pressureNames={'maxCrushingPressure':'Max_Crushing_Pressure','adjustedCrushingPressure':'Adjusted_Crushing_Pressure',
        'initialAllowableGradient':'Initial_Allowable_Gradient','allowableGradient':'Allowable_Gradient','boyleGradient':'Deco_Gradient'}
    radiusNames={'initialRadius':'Initial_Critical_Radius','adjustedInitialRadius':'Adjusted_Critical_Radius','regeneratedRadius':'Regenerated_Radius'}
    for name,attr in pressureNames.items():
        for gas,suffix in [('Nitrogen','N2'),('Helium','He')]:result[name+gas+'Bar']=[v*f for v in getattr(state,attr+'_'+suffix)]
    for name,attr in radiusNames.items():
        for gas,suffix in [('Nitrogen','N2'),('Helium','He')]:result[name+gas+'Metres']=list(getattr(state,attr+'_'+suffix))
    for name,attr,factor in [('maxActualGradientBar','Max_Actual_Gradient',f),('surfacePhaseVolumeMin','Surface_Phase_Volume_Time',1),
            ('totalPhaseVolumeMin','Phase_Volume_Time',1),('previousPhaseVolumeMin','Last_Phase_Volume_Time',1),
            ('ambientOnsetBar','Amb_Pressure_Onset_of_Imperm',f),('tensionOnsetBar','Gas_Tension_Onset_of_Imperm',f)]:
        result[name]=[v*factor for v in getattr(state,attr)]
    def tissues(n,h):return dict(nitrogenBar=[v*f for v in getattr(state,n)],heliumBar=[v*f for v in getattr(state,h)])
    for name,n,h in [('decoStartTissues','N2_Pressure_Start_of_Deco_Zone','He_Pressure_Start_of_Deco_Zone'),
                     ('ascentStartTissues','N2_Pressure_Start_of_Ascent','He_Pressure_Start_of_Ascent'),
                     ('segmentStartTissues','Initial_Nitrogen_Pressure','Initial_Helium_Pressure')]:result[name]=tissues(n,h)
    result.update(surfaceBar=state.Barometric_Pressure*f,vapourBar=state.Water_Vapor_Pressure*f,
        otherGasesBar=state.Constant_Pressure_Other_Gases*f,maximumFirstStopMetres=state.First_Stop_Depth,
        decoZoneStartMin=state.Run_Time_Start_of_Deco_Zone,savedRuntimeMin=state.Run_Time_Start_of_Ascent,
        savedSegmentCount=state.Segment_Number_Start_of_Ascent,criticalVolumeIterations=0,decoPhaseVolumeMin=state.Deco_Phase_Volume_Time)
    return result
