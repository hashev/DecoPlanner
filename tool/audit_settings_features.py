import json,hashlib,pathlib,sys
root=pathlib.Path(__file__).resolve().parents[1]; src=root/'docs/ui/feature-map.json'; data=json.loads(src.read_text())
groups=[
(['openCircuitDecoGasTable','decoGasSwitchDepth','decoGasOxygenPercent','decoGasHeliumPercent','closedCircuitDecoGasTable','decoGasPO2','decoGasMinimumStopTime','decoGasLostGas','decoGasSetPreviousButton','decoGasSetNextButton','decoGasSetsSelectorComboBox','decoGasSetsTable','decoGasSetsSwitchDepth','decoGasSetsOxygenPercent','decoGasSetsHeliumPercent','decoGasSetsDeleteButton','decoGasSetsAddButton','decoGasSetsClearButton','decoGasSetsSaveButton'], 'Набор выбирается по имени; копия списка, редактирование depth/O₂/He/lost/mode/SP/minimum, clear, Apply и отдельный save/delete каталога.', ['lib/ui/features/plan/switches_editor.dart','lib/ui/features/documents/catalog_view.dart'],['test/ui/switches_editor_test.dart','test/ui/catalog_view_test.dart']),
(['generalDescentRateField','generalAscentRateField','generalSaveButton','generalDecoModelChoiceBox','minimumStopDurationChoiceBox','altitudeSeaLevelRadio','altitudeAltitudeLevelRadio','altitudeInputField','altitudeAcclimatizedCheckBox','altitudeHoursAtAltitudeField','altitudeHoursToReachField','altitudeStartingAltitudeField','altitudeSaveButton','openCircuitSACbottomField','openCircuitSACdecoField','openCircuitSaveButton','closedCircuitLowSetpointChoiceBox','closedCircuitSaveButton','closedCircuitRatioStopsChoiceBox','closedCircuitOCRbottomTextField','closedCircuitOCRdecoTextField','buhlmannSettingsLastStopCheckbox','buhlmannSettingsGFloTextField','buhlmannSettingsGFhiTextField','buhlmannSettingsBoption','buhlmannSettingsCoption','buhlmannSettingsSaveButton','vpmSettingsConservatismChoiceBox','vpmSettingsSaveButton'], 'S01 typed draft с Apply/Cancel/Save defaults. Altitude time подписан в минутах; last-stop — физическая глубина, ratio stops — view preference. GF только B/C, VPM conservatism0–4.', ['lib/ui/features/plan/settings_editor.dart','lib/app/planner_app.dart'],['test/ui/settings_editor_test.dart','test/ui/document_session_test.dart']),
(['generalUnitsChoiceBox','themeLightRadioButton','themeDarkRadioButton','themeSaveButton'], 'Units/theme применяются и сохраняются сразу, не требуют отдельного Save и не меняют physical revision.', ['lib/app/planner_app.dart','lib/ui/features/plan/planner_view_model.dart'],['test/ui/planner_app_test.dart','test/ui/planner_view_model_test.dart']),
(['tanksSelectionComboBox','tanksLabelTextField','tanksMetricRadioButton','tanksImperialRadioButton','tanksInnerVolumeTextField','tanksPressureRatingTextField','tanksCapacityTextField','tanksAddButton','tanksSaveButton','tanksDeleteButton'], 'Каталог с именем/выбором/CRUD, metric L/bar либо imperial nominal CuFt/PSI. Units выбираются до модального редактора. Применение — физическая копия, удаление не меняет план.', ['lib/ui/features/documents/catalog_view.dart','lib/ui/features/plan/gas_usage_view.dart'],['test/ui/catalog_view_test.dart','test/ui/gas_usage_view_test.dart']),
(['diveProfileSettingsClearPreviousProfile','diveProfileSettingsOnlyShowAscent','diveProfileSettingsDontClearOnReset','diveProfileSettingsSaveButton','diveProfileClearProfileButton'], 'S02 auto-retain previous profile (обратный смысл Clear previous), ascent-only, keep-on-reset. Параметры сохраняются сразу. P05 Clear comparisons очищает сохранённые наложения с подтверждением; численный текущий результат остаётся источником основного графика.', ['lib/app/planner_app.dart','lib/ui/features/documents/document_session.dart','lib/ui/features/plan/profile_view.dart'],['test/ui/document_session_test.dart','test/ui/profile_view_test.dart']),
(['helpButton','userGuideTab','tutorialsWebView'], 'Локальная справка и notices доступны из app bar/настроек; WebView заменён встроенным offline-текстом.', ['lib/app/planner_app.dart','assets/help/planner.txt'],['test/ui/planner_app_test.dart']),
(['settingsButton'], 'Постоянный destination Настройки вместо toggle toolbar.', ['lib/app/planner_app.dart'],['test/ui/planner_app_test.dart'])]
lookup={key:(desc,impl,tests) for keys,desc,impl,tests in groups for key in keys}
types={'Button','ToggleButton','CheckBox','TextField','ChoiceBox','RadioButton','ComboBox','WebView','Tab','TableView','TableColumn'}
rows=[]
for entry in data['entries']:
 if entry['target']['screen'] not in {'P03','S01','S02'} or entry['source']['type'] not in types: continue
 key=entry['source']['id']
 if key not in lookup: raise Exception(('Unmapped',entry['id'],key,entry['source']['type']))
 desc,impl,tests=lookup[key]
 for path in impl+tests:
  if not (root/path).exists(): raise Exception(('Missing evidence',path))
 rows.append({'legacy_id':entry['id'],'control':key,'screen':entry['target']['screen'],'behavior':desc,'implementation':impl,'tests':tests})
out={'schema_version':1,'scope':'P03/S01/S02 functional bindings; structural containers/labels inherit parent layout, not counted as separate actions','source':str(src.relative_to(root)),'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'verification':'Source mapping plus listed behavioral tests. Not a claim of native testing every legacy control.','entries':rows}
report=root/'docs/development/settings-feature-coverage.json'
if '--write' in sys.argv:
 report.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
elif json.loads(report.read_text()) != out:
 raise SystemExit('Settings feature report is stale; inspect changes before --write')
print(len(rows),'mapped controls')
