# Optional local reference archive

The original Windows distribution and the complete reverse-engineering evidence
are stored in ignored `local/reference/`. They are never runtime dependencies
of the new application and are not part of the publication manifest.

The migration preserved all 1022 file contents, including all 205 protected
original files. The pre-migration inventory and migration report are under
`local/`; they must not be regenerated to accept changed originals.

From the project root:

```sh
python3 local/reference/analysis/tools/manifest.py --verify
python3 docs/ui/tools/audit_design.py --with-reference
python3 tool/export_legacy_baseline.py
```

The original analysis tools resolve their input root relative to their own
location. The mirrored `analysis/`, `business/`, `runtime/` and `update/` paths
therefore remain valid. Tool versions and research commands are recorded in
`local/reference/analysis/README.md`. Historical links there describe the old
research workspace; current authored calculation documents remain under
`docs/calculations/` in the application repository.

Public static design validation needs no archive:

```sh
python3 docs/ui/tools/check_contrast.py
python3 docs/ui/tools/audit_design.py
```

The public report explicitly says that source/numeric/protected-file checks
were not requested. Requesting `--with-reference` with an unavailable archive
fails; it must never be treated as a successful verification. Regenerating the
legacy map requires the archive, while rendering current SVG design data does
not. Active private source paths in JSON are relative to `local/reference/`.

No original Java binaries, decompiled sources, runtime, registration logic or
branding may enter the Dart application's production dependencies.
