# SAP BTP Agentic Infrastructure as Code

Versionierte Landing-Zone für DEV, TEST und PROD mit getrennten BTP- und
Cloud-Foundry-States. Die aktive, nicht geheime Konfiguration liegt in
[BTP/landing-zone.yaml](BTP/landing-zone.yaml).

- [Deployment, State-Erhalt und Migration](docs/MODULAR_LANDING_ZONE.md)
- [Enterprise-Beispiel mit drei Umgebungen](examples/landing-zone.enterprise.yaml)
- [Lokale Prüfungen ohne Infrastrukturänderungen](scripts/check_landing_zone.py)
- [Attributreferenz für alle implementierten Ressourcen](docs/ATTRIBUTE_REFERENCE.md)
- [Schema v2, dynamischer Servicekatalog und Voraussetzungen](docs/SCHEMA_CATALOG_TEMPLATE.md)
- [JSON Schema für Editor und CI](schemas/landing-zone.schema.json)
- [AWS-Beispiel](examples/landing-zone.aws.yaml) / [Azure-Beispiel](examples/landing-zone.azure.yaml)

Die aktive Konfiguration erhält DEV und den bisher geplanten TEST-Subaccount.
TEST-CF und zusätzliche Services bleiben zunächst aus, PROD ist im Trial
deaktiviert. Keine Credentials, persönlichen Zugänge oder State-Dateien in YAML
oder Git eintragen.

Für die Python-Prüfungen zuerst die Abhängigkeiten aus scripts/requirements.txt
in einer eigenen virtuellen Umgebung installieren. Danach deren Python für
scripts/check_landing_zone.py verwenden; siehe Deployment-Dokumentation.

Das Skript verwendet frische temporäre Provider-Verzeichnisse, deaktiviert die
Backends für die Initialisierung und führt ausschließlich Validierungen und
lokale Tests mit Mock-Providern aus. Es startet keine HCP-Runs und führt keine
realen Plans, Applies, Imports oder State-Migrationen aus.

Der aktuelle Prüf- und Integrationsvertrag einschließlich der Audit-Korrekturen,
CI-Pipeline, HCP-Trigger-Vorschläge und Handoff-Übergangsvoraussetzung steht in
[Audit-Korrekturen und PR-Prüfvertrag](docs/AUDIT_REMEDIATION.md).
Für die vollständige lokale Testsuite ist zusätzlich der dort dokumentierte,
gepinnte Gitleaks-Scanner erforderlich.
