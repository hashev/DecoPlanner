# Calculation fixtures

`legacy_baseline/` contains semantic numeric observations exported from the
previous research run of the supplied DecoPlanner 4.6.3 archive. Every record
identifies the archive and full original result by SHA-256. It contains no Java
source, bytecode or unfiltered object dump. Original complete evidence remains
in the ignored local reference archive.

These observations are not independent corrected-model expectations. Records
with `legacy-error` preserve the existence of a failure, not a successful plan.
The original requests and results must not be refreshed to match the Dart code.

`parameters/buhlmann-observed.json` contains numeric coefficient observations,
not executable code. Its four tables preserve the research variants; independent
cross-check and the corrected model version are required before production use.
No permission or safety certification of the original software is inferred.

Regeneration, when the optional reference archive is available:

```sh
python3 tool/export_legacy_baseline.py
```

Independent and corrected-regression data are kept in separate directories
with their own source, normalization, commands, model version and tolerances.
The reviewed inventory covers every JSON, including diagnostic-only external
results. Run `python3 tool/audit_numerical_fixtures.py` from the repository root.
See `docs/models/numerical-fixtures.md` for roles and field assertion contracts.
