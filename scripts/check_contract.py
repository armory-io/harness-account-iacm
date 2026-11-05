#!/usr/bin/env python3
"""Contract between this repo and the templates repos.

  - every account variable a templates repo needs (variables/required.yaml) exists in base
  - every override only touches identifiers that exist in base
  - production overrides are empty or explicitly justified (warn)
usage: check_contract.py <templates-repo-dir>...
"""
import sys
from pathlib import Path

import yaml

root = Path(__file__).resolve().parent.parent
base = set(yaml.safe_load((root / "base/account_variables.yaml").read_text())["variables"])
bad = []

for d in sys.argv[1:]:
    req = set(yaml.safe_load((Path(d) / "variables/required.yaml").read_text())["account_variables"])
    for name in sorted(req - base):
        bad.append(f"{d}: requires account variable {name!r} which base/account_variables.yaml does not define")

for env in ("sandbox", "production"):
    ov = (yaml.safe_load((root / f"accounts/{env}/overrides.yaml").read_text()) or {}).get("overrides") or {}
    for name in sorted(set(ov) - base):
        bad.append(f"accounts/{env}/overrides.yaml: {name!r} is not defined in base")
    if env == "production" and ov:
        print(f"warn: production has overrides {sorted(ov)}; production should equal base")

if bad:
    print("\n".join(f"FAIL {b}" for b in bad), file=sys.stderr)
    sys.exit(1)
print("contract: ok")
