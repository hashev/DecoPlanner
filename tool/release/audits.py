"""Public offline audits; never recapture reference results."""
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AUDITS = [
    "tool/audit_numerical_fixtures.py", "tool/audit_calculation_coverage.py",
    "tool/audit_corrections.py", "tool/audit_settings_features.py",
    "tool/audit_vpm_multilevel_reference.py", "tool/audit_vpm_redescent_reference.py",
    "docs/ui/tools/audit_design.py",
]

if __name__ == "__main__":
    import sys
    for audit in AUDITS:
        subprocess.run([sys.executable, audit], cwd=ROOT, check=True)
    subprocess.run(["openspec", "validate", "--specs", "--strict"], cwd=ROOT, check=True)
    for change in sorted((ROOT / "openspec/changes").iterdir()):
        if change.is_dir() and (change / ".openspec.yaml").exists():
            subprocess.run(["openspec", "validate", change.name, "--strict"], cwd=ROOT, check=True)
