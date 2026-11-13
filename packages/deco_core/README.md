# deco_core

Independent pure Dart calculation package. No Flutter, JVM, network, filesystem,
FFI or reference-oracle dependency in production code. SDK: Dart3.11.4.

Implemented APIs are exported by `lib/deco_core.dart`:

- Immutable versioned requests/results, full16tissue and22vector VPM state,
  strict finite JSON, physical PressureContext/StopGrid and display conversions.
- Haldane/Schreiner OC/CCR propagation, clipped setpoint movement and level timing.
- Bühlmann B/C1b coefficients, mixed a/b ceilings, depth-linear GF and OC schedule
  prototype. Complete CCR/bailout/multilevel normalization remains open.
- `calculateVpm`: bounded OC critical-volume/stop search with corrected N2/He
  weights, independently checked17full profiles, including c0–c4 and CV off.
  Full CCR/bailout/multilevel/imperial integration remains open.
- Altitude/travel preparation, surface interval tissue/bubble recovery primitives.
  Full-sequence validation is still in progress.
- Baker seven-band CNS/OTU policy. Above1.6ATA, CNS is unavailable with a reason,
  while decompression/OTU continue. Unknown CNS survives SI and serialization.
- Gas properties, custom mix, ideal/vdW partial-pressure mixing, recorded Z table,
  top-off/equalizer/cylinder conversion and fill costs with a flat top-up fee.
  Continuous blending and schedule gas usage remain open.

CalculationBudget bounds all numerical searches and checks cancellation/time
cooperatively. A future application worker must additionally enforce an external
isolate timeout; that worker and the product UI are not implemented yet.

Tests run through the official Dart MCP runner, or locally `dart test` from this
package. See `docs/models/` at the repository root for policy, correction registry,
independent fixture provenance, accepted tolerances and remaining limitations.
Reference capture tools use optional ignored `local/oracles`; tests need only the
public fixtures. Legacy observations are preserved separately from corrected
independent expectations. Matching fixtures is not physiological certification.
