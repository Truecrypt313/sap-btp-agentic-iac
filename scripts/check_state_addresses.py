#!/usr/bin/env python3
"""Audit source addresses against the independent, read-only MCP inventory."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
contract = json.loads((ROOT / "schemas/state-address-contract.json").read_text())
checked = 0
for file, addresses in contract.items():
    if file == "provenance":
        continue
    source = (ROOT / file).read_text()
    for address in addresses:
        path = address.removeprefix("module.srvc_baseline.")
        parts = path.split(".")
        kind, resource_type, name = ("data", parts[1], parts[2]) if parts[0] == "data" else ("resource", parts[0], parts[1])
        pattern = rf'(?m)^{kind}\s+"{re.escape(resource_type)}"\s+"{re.escape(name)}"\s*\{{'
        matches = list(re.finditer(pattern, source))
        if len(matches) != 1:
            raise SystemExit("State address missing or duplicated: " + address)
        block = source[matches[0].start():source.index("\n}", matches[0].end())]
        if address not in ["btp_subaccount.additional","btp_subaccount_role_collection_assignment.emergency_administrators"] and re.search(r"(?m)^\s*(count|for_each)\s*=", block):
            raise SystemExit("Legacy address became indexed: " + address)
        checked += 1
module = (ROOT / "BTP/main.tf").read_text().split('module "srvc_baseline" {', 1)[1].split("\n}", 1)[0]
if re.search(r"(?m)^\s*(for_each|count)\s*=", module) or not re.search(r'source\s*=\s*"\./modules/srvc-baseline"',module):
    raise SystemExit("Legacy baseline module address/source changed")
for file in ["BTP/main.tf","BTP/modules/srvc-baseline/srvc_baseline.tf","CloudFoundry/main.tf"]:
    text = (ROOT / file).read_text()
    if re.search(r"(?m)^\s*count\s*=", text):
        raise SystemExit("count would change legacy instance addresses: " + file)
print(f"State address contract: {checked} existing/planned base addresses retained; legacy module unindexed.")
