#!/usr/bin/env python3
"""Check/write the independent project envelope schema; reuse landing-zone v2."""
import argparse
import json
from project_configuration import ROOT, project_schema


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    path = ROOT / "schemas/project.schema.json"
    content = json.dumps(project_schema(), indent=2, ensure_ascii=False) + "\n"
    if args.write:
        path.write_text(content)
    elif not path.exists() or path.read_text() != content:
        raise SystemExit("Projekt-Schema veraltet; build_project_schema.py --write ausführen")
    print("Project envelope schema agrees with the existing landing-zone schema.")


if __name__ == "__main__":
    main()
