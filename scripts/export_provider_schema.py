#!/usr/bin/env python3
"""Refresh locked provider schemas in disposable backend-free copies; render coverage."""
from pathlib import Path
import argparse
import json
import os
import re
import shutil
import subprocess
import tempfile
from schema_model import CONFIGURATION, hcl_type

ROOT = Path(__file__).resolve().parents[1]
MAPPING = {
    "btp_directory": {
        "name": "project.directory.name",
        "description": "project.directory.description",
        "features": "project.directory.features",
        "labels": "project_id aus der Projektidentität",
        "parent_id": "geprüfter Laufzeitinput directory_parent_id",
        "subdomain": "Projekt-ID + directory bei AUTHORIZATIONS",
    },
    "btp_subaccount": {
        "name": "environments.*.name; sonst Stage + project_name",
        "subdomain": "environments.*.subdomain; sonst bestehende UUID-Ableitung",
        "description": "environments.*.description",
        "region": "environments.*.region, aufgelöst durch region-catalog",
        "parent_id": "environments.*.parent_id",
        "labels": "environments.*.labels + reservierte stage/costcenter",
        "usage": "environments.*.usage",
        "beta_enabled": "environments.*.beta_enabled",
        "skip_auto_entitlement": "environments.*.skip_auto_entitlement",
    },
    "btp_subaccount_environment_instance": {
        "subaccount_id": "abgeleitet aus dem Subaccount derselben Umgebung",
        "name": "environments.*.cloud_foundry.name; sonst eindeutige Subdomain",
        "environment_type": "environments.*.cloud_foundry.environment_type (CF-Vertrag)",
        "service_name": "environments.*.cloud_foundry.service_name (CF-Vertrag)",
        "plan_name": "environments.*.cloud_foundry.plan",
        "landscape_label": "environments.*.cloud_foundry.landscape_label; eindeutiger Katalogtreffer",
        "parameters": "environments.*.cloud_foundry.parameters / parameters_key; sonst instance_name",
        "timeouts": "environments.*.cloud_foundry.timeouts",
    },
    "btp_subaccount_entitlement": {
        "subaccount_id": "abgeleitete Umgebungs-ID",
        "service_name": "service_catalog.*.service_name / services.entitlements.*.service_name / dokumentiertes Preset",
        "plan_name": "service_catalog.*.plan_name / services.entitlements.*.plan_name / Preset.plan",
        "plan_unique_identifier": "Katalogdefinition, Custom-Entitlement oder Preset.plan_unique_identifier",
        "amount": "Definition.amount / services.catalog_amounts / Preset.amount; Katalog-Kategorie prüfen",
    },
    "btp_subaccount_service_instance": {
        "subaccount_id": "abgeleitete Umgebungs-ID",
        "name": "services.instances.*.name / instance_options.name / service_catalog.*.instance.name",
        "labels": "Instanzoptionen.labels",
        "parameters": "Instanzoptionen.parameters oder parameters_key aus sensitivem Runtime-Input",
        "shared": "Instanzoptionen.shared; tatsächlicher Plan muss shareable sein",
        "serviceplan_id": "Instanzoptionen.serviceplan_id als geprüfter Lookup oder tatsächliche Katalog-ID",
        "serviceplan_name": "bei use_plan_names: offering + plan; kein gleichzeitiges ID-Argument",
        "service_offering_name": "bei use_plan_names: services.instances.*.offering / Preset / Katalogdefinition",
        "timeouts": "Instanzoptionen.timeouts",
    },
    "btp_subaccount_subscription": {
        "subaccount_id": "abgeleitete Umgebungs-ID",
        "app_name": "services.subscriptions.*.app_name / Katalogdefinition.subscription.app_name / Preset",
        "plan_name": "services.subscriptions.*.plan_name / Katalogdefinition.plan_name / Preset",
        "parameters": "Subscription-Optionen.parameters oder parameters_key",
        "timeouts": "Subscription-Optionen.timeouts",
    },
    "btp_subaccount_role_collection": {
        "subaccount_id": "abgeleitete Umgebungs-ID",
        "name": "role_collections.*.name",
        "description": "role_collections.*.description",
        "roles": "role_collections.*.roles.*",
    },
    "btp_subaccount_role_collection_assignment": {
        "subaccount_id": "abgeleitete Umgebungs-ID",
        "role_collection_name": "administrator_options.role_collection_name / role_assignments.*.role_collection_name / role_collection_key als Ressourcenreferenz",
        "user_name": "administrators / bestehender DEV-HCP-Input / role_assignments.*.user_name",
        "group_name": "role_assignments.*.group_name",
        "attribute_name": "role_assignments.*.attribute_name",
        "attribute_value": "role_assignments.*.attribute_value",
        "origin": "administrator_options.origin / role_assignments.*.origin",
    },
    "cloudfoundry_space": {
        "name": "environments.*.cloud_foundry.spaces.*.name",
        "org": "validierter BTP-Output; im bestehenden DEV-Root unveränderter cf_org_id-Input",
        "allow_ssh": "spaces.*.allow_ssh",
        "isolation_segment": "spaces.*.isolation_segment",
        "labels": "spaces.*.labels",
        "annotations": "spaces.*.annotations",
    },
    "cloudfoundry_space_role": {
        "space": "abgeleitete ID des Space mit demselben Schlüssel",
        "type": "spaces.*.roles.*.type / managers/developers / bestehende DEV-Rollen",
        "user": "roles.*.user / legacy_manager.user / legacy_developer.user",
        "username": "roles.*.username / managers/developers / Legacy-HCP-Input",
        "origin": "roles.*.origin / member_origin / legacy_manager.origin / legacy_developer.origin",
    },
}
RULES = {
    "btp_directory": {
        "features": "DEFAULT erforderlich; AUTHORIZATIONS benötigt ENTITLEMENTS. Pro Pfad höchstens ein erweitertes Directory, max. fünf Ebenen.",
        "parent_id": "Live geprüfter Parent-Pfad im gleichen Global Account; bestehende Subaccounts werden nicht verschoben.",
        "name": "Bestehende Directories nur als projektgebundene Data Source referenzieren, niemals doppelt erstellen.",
    },
    "btp_subaccount": {
        "name": "1–255 Zeichen, kein /.",
        "description": "Maximal 300 Zeichen.",
        "labels": "Provider: max. 10 Schlüssel, Werte max. 63 Zeichen. Template reserviert zwei Schlüssel.",
        "usage": "UNSET, NOT_USED_FOR_PRODUCTION, USED_FOR_PRODUCTION; letzteres nur Enterprise-PROD.",
        "subdomain": "Regional eindeutig; Template erzwingt Kleinbuchstaben/Ziffern/Bindestriche.",
        "skip_auto_entitlement": "Creation-only; null bewahrt bisherigen Zustand. Nach Import nicht rekonstruierbar.",
    },
    "btp_subaccount_entitlement": {
        "amount": "Ganzzahl 1–2000000000, nur SERVICE/QUOTA_BASED_APPLICATION/PLATFORM/ENVIRONMENT. Positive Deltas werden gemeinsam geprüft.",
        "plan_unique_identifier": "Bei mehreren Preisvarianten zwingend explizit auswählen; keine erste Variante nehmen.",
    },
    "btp_subaccount_service_instance": {
        "serviceplan_id": "Alternativ zu serviceplan_name + service_offering_name; echter, bereiter Katalogplan.",
        "serviceplan_name": "Benötigt service_offering_name, schließt serviceplan_id aus.",
        "service_offering_name": "Benötigt serviceplan_name, schließt serviceplan_id aus.",
        "parameters": "JSON-Objekt; sensible Inhalte nur über Runtime-Referenz; State-Zugriff schützen.",
        "shared": "Nur wenn der tatsächliche Plan shareable=true meldet.",
    },
    "btp_subaccount_subscription": {
        "parameters": "JSON-Objekt; API-Updates nur wenn supports_parameters_updates. Keine geheimen Werte in YAML.",
        "plan_name": "Entitlement + Subaccount-Subscription-Katalog; Planupdates sind anbieterspezifisch.",
    },
    "btp_subaccount_role_collection_assignment": {
        "user_name": "Genau eines von user_name/group_name/attribute_name; 1–256 Zeichen.",
        "group_name": "Benötigt origin; externe Collection wird gelesen, verwaltete Collection per Schlüssel referenziert.",
        "attribute_name": "Benötigt attribute_value und origin.",
        "attribute_value": "Benötigt attribute_name.",
        "origin": "Providerdefault ldap; null erhält Legacy-Verhalten. Custom-IdP nur ausdrücklich wählen.",
        "role_collection_name": "Externer Name oder role_collection_key einer verwalteten Collection; genau eine Quelle. Neue verwaltete Bindungen benötigen expliziten origin.",
    },
    "btp_subaccount_role_collection": {
        "name": "Eindeutig je Subaccount; stabile YAML-Schlüssel. Vorhandene Collections nicht doppelt anlegen.",
        "roles": "Mindestens eine Rolle; jedes Tripel muss im SAP-Katalog eindeutig existieren und erforderliche Attribute müssen belegt sein.",
    },
    "cloudfoundry_space": {
        "org": "UUID; aus dem zugehörigen Workspace-/BTP-Handoff, keine freie YAML-Umleitung.",
        "isolation_segment": "UUID; muss der Parent-Org bereits zugeteilt sein.",
        "labels": "map(string), CF-Metadatenregeln gelten; nicht BTP-map(set(string)).",
        "annotations": "map(string), CF-Metadatenregeln gelten.",
    },
    "cloudfoundry_space_role": {
        "type": "space_manager, space_developer, space_auditor, space_supporter.",
        "user": "UUID; genau eines von user/username. Origin mit user verboten.",
        "username": "Genau eines von user/username; Benutzer braucht bestehende organization_user-Rolle.",
        "origin": "Benötigt username; nicht zusammen mit user.",
        "space": "UUID; automatisch aus dem Space desselben States.",
    },
}
REPLACE = {
    "btp_directory": {"parent_id", "subdomain"},
    "btp_subaccount_role_collection": {"subaccount_id", "name"},
    "btp_subaccount": {"region", "subdomain", "parent_id", "skip_auto_entitlement"},
    "btp_subaccount_entitlement": {"subaccount_id", "service_name", "plan_name"},
    "btp_subaccount_environment_instance": {"subaccount_id", "name", "environment_type", "service_name", "landscape_label"},
    "btp_subaccount_role_collection_assignment": {"subaccount_id","role_collection_name","user_name","group_name","attribute_name","attribute_value","origin"},
    "btp_subaccount_service_instance": {"service_offering_name"},
    "btp_subaccount_subscription": {"subaccount_id", "app_name"},
    "cloudfoundry_space": {"org"},
    "cloudfoundry_space_role": {"type", "user", "username", "origin", "space"},
}
DATA = {"btp_directories", "btp_directory", "btp_regions","btp_globalaccount","btp_globalaccount_entitlements_with_data_centers","btp_directory_entitlements",
        "btp_subaccount_entitlements","btp_subaccount_service_plan","btp_subaccount_subscriptions",
        "btp_subaccount_environments","btp_subaccount_role_collection","btp_subaccount_roles"}


def capture():
    schemas = {}
    with tempfile.TemporaryDirectory(prefix="locked-provider-schema-") as directory:
        target = Path(directory)
        for name in ["BTP","CloudFoundry","examples"]:
            shutil.copytree(ROOT/name, target/name, ignore=shutil.ignore_patterns(".terraform","*.tfstate*","*.tfvars*",".env*","terraform.tfstate*"))
        for name in ["BTP","CloudFoundry"]:
            # Remove ONLY the disposable backend config; never initialize HCP.
            (target/name/"cloud.tf").unlink()
            env = os.environ.copy()
            env.pop("TF_WORKSPACE", None)
            env.update(TF_DATA_DIR=str(target/"data"/name),TF_INPUT="0")
            subprocess.run(["terraform","init","-backend=false","-lockfile=readonly","-no-color"],cwd=target/name,env=env,check=True,stdout=subprocess.DEVNULL)
            result = subprocess.run(["terraform","providers","schema","-json"],cwd=target/name,env=env,text=True,capture_output=True,check=True)
            schemas.update(json.loads(result.stdout)["provider_schemas"])
    selected = {}
    for key, provider in schemas.items():
        if key.endswith(("/sap/btp","/cloudfoundry/cloudfoundry")):
            selected[key] = {
                "resource_schemas": {k:v for k,v in provider["resource_schemas"].items() if k in MAPPING},
                "data_source_schemas": {k:v for k,v in provider["data_source_schemas"].items() if k in DATA},
            }
    return {"format_version":1,"versions":{"sap/btp":"1.27.0","cloudfoundry/cloudfoundry":"1.18.0"},
            "provenance":"terraform providers schema -json from locked binaries; cloud config removed only in disposable copies",
            "provider_schemas":selected}


def cell(value):
    return str(value).replace("|", "\\|").replace("\n", " ")


def render(snapshot):
    lines = [
        "# Attributreferenz: gelockte Provider und Landing-Zone-Schema",
        "",
        "Generiert aus den installierten Provider-Binaries: SAP/btp 1.27.0 und CF 1.18.0.",
        "Pflichtstatus bezieht sich auf das Provider-Schema; YAML darf Pflichtwerte ableiten.",
        "JSON-Schema exportiert keine Validatoren oder RequiresReplace-Planmodifier. Die",
        "folgenden Regeln/Risiken wurden zusätzlich im Quellcode derselben Tags geprüft.",
        "API-/Broker-Regeln können darüber hinausgehen; keine Ersatzfreiheit wird zugesichert.",
        "",
    ]
    coverage = {}
    for provider, schema in snapshot["provider_schemas"].items():
        for name, resource in schema["resource_schemas"].items():
            attrs = resource["block"]["attributes"]
            writable = {k for k,v in attrs.items() if v.get("required") or v.get("optional")}
            missing = writable - MAPPING[name].keys()
            stale = MAPPING[name].keys() - writable
            if missing or stale:
                raise SystemExit(f"Unmapped/stale provider inputs: {name}: {sorted(missing | stale)}")
            coverage[name] = {"writable":sorted(writable),"covered":sorted(writable),"readonly":sorted(attrs.keys()-writable)}
            source = (
                "https://github.com/SAP/terraform-provider-btp/blob/v1.27.0/btp/provider/resource_"+name.removeprefix("btp_")+".go"
                if name.startswith("btp_") else
                "https://github.com/cloudfoundry/terraform-provider-cloudfoundry/blob/v1.18.0/cloudfoundry/provider/resource_"+name.removeprefix("cloudfoundry_")+".go"
            )
            lines += ["## "+name, "", "[Versionierte Primärquelle]("+source+")", "",
                      "| Attribut | Typ | Status | YAML/Quelle | Werte, Abhängigkeiten und Risiko |",
                      "|---|---|---|---|---|"]
            for key, attr in attrs.items():
                status = "Pflicht" if attr.get("required") else "Optional" if attr.get("optional") else "Nur gelesen"
                if attr.get("computed"):
                    status += ", computed"
                if attr.get("sensitive"):
                    status += ", sensitiv"
                if attr.get("deprecated"):
                    status += ", deprecated"
                data_type = json.dumps(attr.get("type", {"object": {k:v.get("type") for k,v in attr.get("nested_type",{}).get("attributes",{}).items()}}))
                rule = RULES.get(name,{}).get(key,"Provider-/API-Plan prüfen.")
                if key not in writable:
                    rule = "Nicht als Input erlaubt. "+attr.get("description","").split("\n")[0]
                elif key in REPLACE.get(name,set()):
                    modifier = "RequiresReplaceIfConfigured" if key == "service_offering_name" or (name == "btp_directory" and key == "subdomain") else "RequiresReplace"
                    rule += " " + modifier + "; Löschschutz/State-Abhängigkeiten beachten."
                elif key == "timeouts":
                    rule += " Objekt mit create/update/delete, je optionaler Go-Duration-String; Template erlaubt positive Einheiten ns/us/ms/s/m/h."
                lines.append("| "+" | ".join(map(cell,[key,data_type,status,MAPPING[name].get(key,"Provider-Ausgabe"),rule]))+" |")
                for nested, field in attr.get("nested_type",{}).get("attributes",{}).items():
                    rule = "Zeitlimit; zu kleine Werte können Timeouts verursachen, ändern keine State-Adresse." if key == "timeouts" else "Teil der exakten Rollenidentität; gegen den SAP-Rollenkatalog geprüft."
                    lines.append("| "+" | ".join(map(cell,[key+"."+nested,json.dumps(field.get("type")),"Pflicht" if field.get("required") else "Optional",MAPPING[name].get(key,"")+"."+nested,rule]))+" |")
            lines += [""]
    lines += ["## Jedes YAML-Attribut", "",
              "Die Tabelle beschreibt auch Template-Felder, die keine Provider-Argumente sind.",
              "Objekte/Maps mit null erhalten keine erfundenen API-Defaults. Direkte und",
              "Runtime-Parameterquellen sind gegenseitig ausgeschlossen. Alle Pfade sind",
              "zusätzlich im maschinenlesbaren JSON Schema enthalten.", "",
              "| Pfad | Terraform-Typ | YAML-Pflicht | Default | Einschränkungen und Änderungsrisiko |",
              "|---|---|---|---|---|"]
    def walk(node, path):
        if node["kind"] == "object":
            if path:
                lines.append("| "+" | ".join(map(cell,[path,"object","ja" if node["required"] else "nein",json.dumps(node["default"]),"Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade."]))+" |")
            for key, child in node["properties"].items():
                walk(child, path+"."+key if path else key)
        elif node["kind"] == "map":
            lines.append("| "+" | ".join(map(cell,[path,"map","ja" if node["required"] else "nein",json.dumps(node["default"]),"Stabile Schlüssel; Entfernen bereits verwalteter Schlüssel kann Löschungen planen."]))+" |")
            walk(node["items"],path+".*")
        else:
            rules = [f"{k}={json.dumps(node[k])}" for k in ["enum","format","pattern","minimum","maximum","minLength","maxLength"] if k in node]
            if any(x in path for x in [".region",".subdomain",".parent_id",".skip_auto_entitlement"]):
                rules.append("Regions-/Identitäts-/Ersetzungsrisiko; vorher Plan prüfen.")
            elif any(x in path for x in [".origin",".user",".group",".attribute",".role"]):
                rules.append("Berechtigungsänderung; Subjekt-Kombination und vorhandene Mitgliedschaft prüfen.")
            elif "parameters" in path:
                rules.append("Nur nicht geheime JSON-Objekte oder getrennte sensitive Runtime-Referenz; Broker-Schema zusätzlich maßgeblich.")
            else:
                rules.append("Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan.")
            lines.append("| "+" | ".join(map(cell,[path,hcl_type(node),"ja" if node["required"] else "nein",json.dumps(node["default"]),node.get("description","")+"; ".join(rules)]))+" |")
    walk(CONFIGURATION,"")
    lines += ["", "## Grenzen der Abdeckung", "",
        "- Alle beschreibbaren Attribute der implementierten Ressourcentypen sind direkt oder abgeleitet verbunden.",
        "- Berechnete Felder wie CF-Environment-custom_labels, Space.quota, IDs, Zeitstempel und Status sind keine YAML-Eingaben.",
        "- Eine CF-Space-Quota braucht eine eigene Ressource; hier wird keine Schreibfähigkeit erfunden.",
        "- Broker-Parameterschemas werden nicht vollständig lokal ausgeführt. Die API prüft dienstspezifische Semantik.",
        "- Role Collections werden explizit über YAML verwaltet; Zuweisungen sind davon getrennt und standardmäßig leer.",
        "- Org-Mitgliedschaften, Isolation-Segment-Entitlements, Service-Bindings und Apps werden nicht erstellt.",
        "- Diese Momentaufnahme ist kein Live-Verfügbarkeits- oder Quotenbeweis. Neue Subaccount-Kataloge sind erst nach deren Existenz lesbar.",
        "- Alle Schema-Beschreibungen stammen aus den jeweiligen SAP-/Cloud-Foundry-Providern (Apache-2.0); Quellen siehe oben.",
        ""]
    return "\n".join(lines), coverage


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--refresh",action="store_true")
    parser.add_argument("--check",action="store_true")
    args=parser.parse_args()
    path=ROOT/"schemas/provider-resources.json"
    snapshot=capture() if args.refresh else json.loads(path.read_text())
    for folder, provider, expected in [("BTP","sap/btp","1.27.0"),("CloudFoundry","cloudfoundry/cloudfoundry","1.18.0")]:
        lock=(ROOT/folder/".terraform.lock.hcl").read_text()
        if not re.search(r'provider "registry\.terraform\.io/'+provider+r'"\s*{\s*version\s*=\s*"'+re.escape(expected)+'"',lock):
            raise SystemExit("Provider lock changed: refresh and review constraints before generating coverage.")
    reference,coverage=render(snapshot)
    outputs={ROOT/"docs/ATTRIBUTE_REFERENCE.md":reference,ROOT/"schemas/coverage.json":json.dumps(coverage,indent=2)+"\n"}
    if args.refresh:
        outputs[path]=json.dumps(snapshot,indent=2)+"\n"
    for target, content in outputs.items():
        if args.check:
            if target.read_text()!=content:
                raise SystemExit("Generated attribute reference drift: "+str(target.relative_to(ROOT)))
        else:
            target.write_text(content)
    print(f"Provider coverage: {len(coverage)} resource types, {sum(len(v['writable']) for v in coverage.values())} configurable attributes.")


if __name__=="__main__":
    main()
