# Projekt-Bootstrap und GitOps

`project_bootstrap.py` bereitet Projekte und ihre HCP-Absicht deterministisch in
Git vor. Ausschließlich Terraform mit dem bereits gepinnten TFE-Provider 0.83.0
verwaltet Workspaces, Variablen, Set-Anbindungen und Leserechte. Der Python-
Run-Client plant und bestätigt Terraform-Runs; er besitzt keine Workspace-,
Credential-, State- oder Berechtigungs-CRUD-Implementierung.

## Dateien und Zuständigkeiten

```text
BTP/config/account-profiles.yaml               bekannte Trial-Konventionen
BTP/config/projects/<id>/
  project.yaml                                Projekt-/Deployment-Schalter
  directory.yaml                              eigenes Directory
  environments/{dev,test,prod}.yaml            BTP, Services, IAM und CF-Absicht
  iam/policies.yaml                           inaktive spätere Governance
  bootstrap.yaml                              ursprünglicher strukturierter Auftrag
BTP/generated/<id>/landing-zone.yaml           bisheriger generierter Terraform-Vertrag
templates/project/                            versionierte sichere Ausgangsvorlagen
HCP/generated/projects.json                   generierter Bootstrap-Registry-Vertrag
HCP/bootstrap/                               eigener Bootstrap-Root/State
HCP/modules/project-workspaces/               wiederverwendbare TFE-Ressourcen
scripts/project_bootstrap.py                  lokale Vorbereitung und PR
scripts/bootstrap_runs.py                     kontrollierte HCP-Run-Orchestrierung
.github/workflows/project-bootstrap.yml       Merge-Plan und getrennte Apply-Freigabe
```

Project ABC wird weder registriert noch importiert. Seine drei bestehenden
Workspaces/States und sämtliche bisherigen Terraform-Roots bleiben unverändert.
Die Registry enthält ausschließlich ausdrücklich registrierte neue Projekte;
sie ist generiert und darf nicht manuell editiert werden. Der bestehende
Landing-Zone-Vertrag bleibt Schema-Version 2, ohne Bootstrap-/Credential-Felder.

## Projekt mit einem Auftrag vorbereiten

```bash
python -m pip install -r scripts/requirements.txt
python scripts/install_gitleaks.py /tmp/project-bootstrap-tools
export GITLEAKS_BINARY=/tmp/project-bootstrap-tools/gitleaks
python scripts/project_bootstrap.py create \
  --project-id projekt-alpha --project-name "Projekt Alpha" \
  --account-profile trial --environments DEV,TEST \
  --cf-environments DEV,TEST --space DEV=backend --space TEST=testing
python scripts/project_bootstrap.py check
python scripts/check_landing_zone.py
python scripts/project_bootstrap.py pr --project-id projekt-alpha
# Erst nach Prüfung veröffentlichen; erfordert einmalig git-/gh-Anmeldung:
python scripts/project_bootstrap.py pr --project-id projekt-alpha --publish
```

`create` arbeitet ohne Netzwerk. Es validiert vollständige Projektquellen,
Datentypen, zentrale Service-Aliase, Profil und projektübergreifende Namen vor
dem ersten Schreibzugriff. Die Repository-Sperre serialisiert konkurrierende
Aufträge; diese erste CLI unterstützt Linux/macOS mit Python 3 und `fcntl`.
Identische Aufträge, auch mit anderer Listenreihenfolge, liefern `unchanged`
ohne Dateien zu überschreiben. Ein abweichender Auftrag mit derselben ID
scheitert. Partielle Schreibfehler werden zurückgerollt; unzugeordnete Artefakte
oder fremde lokale Git-Änderungen werden nicht gelöscht oder committed.

`prepare_project(request, root)` ist dieselbe importierbare Funktion für eine
spätere KI-/MCP-/API-Anbindung. `request` hat genau die dokumentierten Felder
aus `bootstrap.yaml`; unbekannte Felder und Secret-Schlüssel sind verboten.
Ein HTTP-/KI-Dienst ist in dieser Phase nicht implementiert.

Projekt und sämtliche Umgebungen bleiben `enabled: false`; das Directory bleibt
ebenfalls deaktiviert. Ausgewähltes CF wird als vorbereitete Absicht mit
`cloud_foundry.enabled: true` und seinen Spaces eingetragen: Das bestehende
Schema verlangt dies für Spaces. Die beiden Elternschalter verhindern weiterhin
jede CF-/SAP-Bereitstellung. PROD und sein CF bleiben im Trial aus. Die CLI
aktiviert später keine Schalter automatisch.

Services starten mit leerer Auswahl und verwenden den unveränderten zentralen
Service-Katalog. Administrator-, BTP-IAM- und CF-Rollen bleiben leer. BTP-Rollen,
Identity-Provider-Origin und CF-Org-/Space-Rollen sind getrennte Kontexte und
werden erst in einem eigenen Konfigurations-PR ergänzt. Governance bleibt inaktiv.

### Bereits vorhandenes `test-neu`

Für eine erstmalige Erstellung in einem Repository ohne dieses Projekt lautet
der Aufruf:

```bash
python scripts/project_bootstrap.py create \
  --project-id test-neu --project-name "Test Neu" \
  --directory-name Test_Neu --account-profile trial --environments DEV,TEST \
  --cf-environments DEV,TEST --space DEV=backend
```

Hier existiert `test-neu` bereits. Deshalb wird es ausdrücklich registriert,
ohne seine Quellen, Flags, Spaces, IAM oder generierte BTP-YAML zu überschreiben:

```bash
python scripts/project_bootstrap.py register \
  --project-id test-neu --project-name "Test Neu" \
  --directory-name Test_Neu --account-profile trial --environments DEV,TEST \
  --cf-environments DEV,TEST
```

Dieser PR enthält genau diesen Registrierungsbeleg. Auch CF bleibt für das
bestehende `test-neu` vollständig deaktiviert. `backend` wird dort erst mit dem
späteren expliziten CF-Konfigurations-PR ergänzt. `register` akzeptiert nur
vollständig deaktivierte Projekte mit passender Identität; es importiert keine
HCP-/SAP-Ressource. Wiederholung des obigen Aufrufs ist ein No-op.

## Zentrales Trial-Profil

Das versionierte Profil enthält das tatsächliche Account-Profil `trial`, die
bekannte Standardregion `us10`, AWS, den CF-Plan `trial`, DEV/TEST und
`skip_auto_entitlement: true`. Region/Provider sind überprüfte Ausgangswerte,
keine Zusage verfügbarer Landschaften, weiterer Organisationen oder Kapazitäten.
Es gibt keinen künstlichen Zähler und keine angenommene maximale Anzahl von
Directories, Subaccounts oder Spaces. Zusätzliche Quotenfelder werden abgelehnt.
PROD kann nicht über einen Trial-Auftrag ausgewählt werden.

SAP entscheidet beim tatsächlichen Terraform-Plan/Apply anhand der aktuellen
Account-Fähigkeiten, Rechte und Entitlements. Bei einem fehlgeschlagenen
Core-Run gibt der Run-Client einen deutschen Hinweis auf diese Prüfstellen aus,
ohne private Provider-Logs oder Response-Bodies zu veröffentlichen. Quoten von
Project ABC werden niemals automatisch verschoben. Das Profil ersetzt nicht
den obligatorischen [Directory-State-Preflight](DIRECTORY_STABILIZATION.md).

## Einmalige Plattform-Einrichtung nach gesonderter Freigabe

Diese Schritte werden in diesem PR nicht ausgeführt. Danach sind pro Projekt
weder Workspace-UI-Konfiguration noch erneutes Eintragen von Credentials nötig.

1. In `sap-ai-landing-zone` den Plattform-Workspace
   `sap-btp-project-bootstrap` einmalig mit Working Directory `HCP/bootstrap`,
   VCS-Repository `Truecrypt313/sap-btp-agentic-iac`, Branch `main`, Terraform
   1.15.5, Remote Execution und **Auto-Apply aus** einrichten. VCS-Trigger auf
   `/HCP/**`, `/BTP/config/projects/**`, `/BTP/config/account-profiles.yaml`
   und die Bootstrap-Skripte beziehen. Keine automatische Destroy-Zeit oder
   geerbte Projekt-Auto-Destroy-Policy verwenden. Der eigene State enthält
   ausschließlich Bootstrap-Ressourcen; niemals mit einem Legacy-State starten.
2. Eine bestehende VCS-Autorisierung genau einmal referenzieren:
   `vcs_auth = {oauth_token_id = "<ot-ID>"}` oder
   `{github_app_installation_id = "<ghain-ID>"}` als HCL-Terraform-Variable.
   Dies sind Referenz-IDs, keine OAuth-Secret-Werte. Die tatsächliche GitHub-
   Autorisierung wird einmalig in HCP eingerichtet.
3. Zwei dedizierte Leser-Teams und ihre Tokens einmalig bereitstellen. Das
   Directory-Team benötigt auf zukünftigen Core-Workspaces `runs=read`,
   `state_versions=read`; das Output-Team nur `state_versions=read-outputs`.
   Keine Schreib-, Apply-, Variablen- oder Adminrechte vergeben. Die einzelnen
   Workspace-Team-Anbindungen erstellt Terraform automatisch. Die Tokens
   haben damit aggregierten Lesezugriff auf die neu verwalteten Core-Workspaces;
   sie dürfen keine zusätzlichen Legacy-/Organisationsrechte besitzen.
   Zusätzlich einmalig getrennte Orchestrierungs-Teams für Plan, Core-Apply und
   CF-Apply bereitstellen. Ihre Tokens gehören ausschließlich in die jeweiligen
   geschützten GitHub-Environments, niemals in Provider-Credential-Sets.
   `operator_teams` im Bootstrap-Workspace referenziert diese drei Team-IDs:

   ```hcl
   { plan = "<team-ID-Plan>", core_apply = "<team-ID-Core>", cf_apply = "<team-ID-CF>" }
   ```

   Terraform gewährt dem Plan-Team Plan-Rechte auf neue Core-/CF-Workspaces,
   dem Core-Team Apply nur auf neue Core-Workspaces und dem CF-Team Apply nur
   auf neue CF-Workspaces. Variablen-/State-Schreibrechte und Policy-Overrides
   bleiben aus. Operator- und Leser-Teams müssen unterschiedliche IDs besitzen.
   Damit sind keine manuellen Team-Anbindungen pro weiterem Projekt nötig.
4. Wiederverwendbare **nicht globale** HCP-Variable-Sets einmalig einrichten:

   | Set | Einmalig hinterlegte Werte |
   |---|---|
   | BTP-Trial | Terraform-String `globalaccount` (bestehende Global-Account-Subdomain); sensitive Environment-Credentials `BTP_USERNAME`/`BTP_PASSWORD` oder eine bereits unterstützte alternative Provider-Authentifizierung; sensitive `DIRECTORY_PREFLIGHT_HCP_TOKEN` des Directory-Leser-Teams |
   | CF-Trial | sensitive Environment-Credentials `CF_USER`/`CF_PASSWORD` bzw. bestehender unterstützter Auth-Flow, ggf. `CF_ORIGIN`; sensitive `TFE_TOKEN` des Output-Leser-Teams |

   Provider-Credentials nicht zu Terraform-Inputs oder Projekt-YAML kopieren.
   Das CF-API-Ziel kommt ausschließlich aus dem validierten BTP-Handoff.
   Die Sets nicht mit dem privilegierten Bootstrap-TFE-Token vermischen.
5. Im Bootstrap-Workspace `account_bindings` als HCL-Map mit ausschließlich
   öffentlichen Referenz-IDs konfigurieren:

   ```hcl
   {
     trial = {
       btp_variable_set_ids      = ["<varset-ID-BTP>"]
       cf_variable_set_ids       = ["<varset-ID-CF>"]
       directory_reader_team_id = "<team-ID-State>"
       output_reader_team_id    = "<team-ID-Outputs>"
     }
   }
   ```

   Der TFE-Provider des Bootstrap-Workspaces erhält einmalig ein sensitives
   `TFE_TOKEN` mit den nötigen Workspace-/Variablen-/Set-Anbindungs-/Team-Rechten.
   Er liest keine Credential-Werte aus Variable-Sets und erzeugt keine Tokens.
6. Python 3 und HTTPS-Zugriff auf HCP/State-Downloads im späteren BTP-Worker
   sicherstellen. Die Directory-Prüfung blockiert andernfalls aktive Plans.
   Verfügbarkeit der benötigten HCP-Team-/Custom-Permission-Funktionen und der
   vorhandenen SAP-/CF-Zugriffsrechte im Plattform-Setup prüfen.
7. Für die GitOps-Orchestrierung sichere GitHub Environments
   `hcp-bootstrap-plan`, `hcp-project-plan`, `hcp-bootstrap-apply`,
   `hcp-core-apply`, `hcp-cf-apply`
   einrichten; Apply-Environments mit Reviewern und Branch-Beschränkung `main`
   schützen. `main` mit PR-Review und erfolgreicher Landing-Zone-CI schützen.
   Jeweils `HCP_ORCHESTRATION_TOKEN` als Environment-Secret setzen.
   Die beiden Plan-Environments verwenden das Plan-Team-Token; die Core-/CF-
   Apply-Environments jeweils ihr Operator-Team-Token. Für Bootstrap-Apply ein
   eigenes, nur auf den Plattform-Workspace begrenztes Apply-Token verwenden.
   Der anschließende Job für Projekt-Pläne benutzt wieder ausschließlich das
   Plan-Token. Auf dem einmaligen Bootstrap-Workspace dem Plan-Team Plan-/Output-
   Leserechte und beiden Operator-Teams nur Output-Leserechte geben: Der Run-
   Client überprüft damit die tatsächlich verwalteten Ziel-IDs. Keine Organization-
   Tokens für Runs verwenden; HCP erwartet User-/Team-Tokens.
8. Nach Review `bootstrap_enabled=true` im Plattform-Workspace und die
   Repository-Variable `PROJECT_BOOTSTRAP_ENABLED=true` aktivieren. Beide
   Freigaben sind bewusst getrennt von den SAP-Deployment-Schaltern. Die
   Repository-Variable ist ohne Setup nicht gesetzt; der neue Root ist
   standardmäßig ausgeschaltet. Es gibt keinen automatischen Apply nach Merge.
   Nach dem ersten Bootstrap `bootstrap_enabled=true` beibehalten: Abschalten
   oder Entfernen einer Registrierung würde Ressourcen aus `for_each` entfernen
   und durch `prevent_destroy` blockierte Löschungen planen. Zum Pausieren nur
   die GitHub-Orchestrierungsvariable ausschalten; kein State wird aufgegeben.

Neue Core-/CF-Workspaces bekommen automatisch Namen, passende Cloud-Block-Tags,
Working Directories, Version, Remote Execution, VCS-Verbindung, Routing-Inputs
und die passenden Set-/Operator-Anbindungen. `queue_all_runs=false` verhindert frühe
Webhook-Runs vor fertiggestelltem Setup; die Orchestrierung startet die ersten
Plans ausdrücklich. Ein Core erlaubt nur seinen eigenen CF-Workspaces Remote-
State-Zugriff; weder global noch projektweit. Die CF-Provider-Tokens lesen nur
Outputs, während die Directory-Prüfung einen separaten State-Leser benutzt.

## Merge, Plan, Freigabe und Drift

1. Die Projekt-CLI bereitet einen lokalen Feature-Branch und Commit vor;
   `pr --publish` veröffentlicht den PR. Sie nimmt keine fremden lokalen oder
   bereits committed Branch-Änderungen mit. Die vorhandene GitHub-CI prüft auch
   alle Bootstrap-Tests und die generierte Registry. Kein PR führt Live-Jobs aus.
2. Nach Merge plant der neue Workflow bei aktiviertem Plattform-Setup den
   Bootstrap-Root. Der Run ist Apply-fähig, hat aber Auto-Apply explizit aus.
   Ein vorhandener namensgleicher fremder Workspace führt beim TFE-Create zu
   einem Fehler; kein Import und keine automatische Adoption.
   Ein bereits aktiver, exakt passender VCS-Run wird wiederverwendet, damit ein
   zweiter gleichartiger Run nicht hinter seiner eigenen Freigabe wartet.
   Fremde Versionen, Overrides und abgeschlossene/fehlgeschlagene Runs werden
   nicht übernommen. Ältere blockierende Runs müssen ausdrücklich geprüft werden.
3. Bootstrap-Plan prüfen. Anschließend den Workflow auf `main` manuell mit Phase
   `bootstrap`, Run-ID, vollständigem Commit und exakt dieser Freigabe auslösen:
   `apply:sap-btp-project-bootstrap:<run-ID>:<commit>`.
   Das ist eine **HCP-Bootstrap-Freigabe**, keine SAP-BTP-Freigabe.
4. Terraform erstellt die HCP-Objekte. Der Workflow wartet auf den Apply und
   fordert einen weiteren Plan ohne Änderungen. Erst danach werden Core-Pläne
   der registrierten Projekte automatisch angestoßen. Mit den aktuellen
   deaktivierten Quellen erzeugen diese keine SAP-Ressourcen.
5. SAP-Aktivierung erfordert eigene geprüfte Konfigurations-PRs und einzelne
   Core-Pläne/Freigaben. Directory, Subaccount und CF-Organisation weiterhin
   schrittweise aktivieren, wie im Preflight vereinbart. Der Orchestrator setzt
   keine Flags und macht keinen Target-Apply.
6. Nach einem erfolgreichen BTP-Core-Apply und gültigem Handoff CF-Pläne separat
   starten/freigeben. Erst deren Apply verwaltet Spaces/Rollen. Jeder Apply
   erhält einen anschließenden Plan-only-Driftcheck. Drift wird gemeldet, nicht
   automatisch korrigiert.

Direkte CLI-Varianten (Token ausschließlich sicher als Environment bereitstellen):

```bash
python scripts/bootstrap_runs.py plan --phase bootstrap --commit <main-SHA>
# Initialer, nach dem einmaligen Setup ausdrücklich freizugebender Bootstrap:
python scripts/bootstrap_runs.py plan --phase bootstrap --commit <main-SHA> --allow-apply
python scripts/bootstrap_runs.py approve --phase bootstrap \
  --commit <main-SHA> --run-id <run-ID> \
  --approval 'apply:sap-btp-project-bootstrap:<run-ID>:<main-SHA>'
# Standard ist ausschließlich plan-only. Für einen später freizugebenden Plan:
python scripts/bootstrap_runs.py plan --phase core --project-id test-neu \
  --commit <main-SHA> --allow-apply
python scripts/bootstrap_runs.py approve --phase core --project-id test-neu \
  --commit <main-SHA> --run-id <run-ID> \
  --approval 'apply:sap-btp-test-neu-core:<run-ID>:<main-SHA>'
python scripts/bootstrap_runs.py plan --phase cf --project-id test-neu \
  --environment DEV --commit <main-SHA> --allow-apply
```

Der Run-Client verlangt exakt passende `main`-Ingress-Metadaten statt still die
neueste beliebige Konfigurationsversion zu verwenden. Bei VCS-Verzögerung wartet
man auf den passenden Ingress und startet den Befehl erneut. Core/CF-Ziele
müssen mit den tatsächlichen Workspace-IDs aus den öffentlichen Outputs des
Bootstrap-States übereinstimmen; Namensgleichheit genügt nicht. Geprüfte Run-ID,
Workspace und Commit stehen im Freigabetext und bleiben in HCP nachvollziehbar.
Der Driftcheck verwendet ausdrücklich die Konfigurationsversion des bestätigten
Runs, auch wenn während des Applies bereits ein neuer Commit gemergt wurde.
Auch die nachgelagerten Projekt-Pläne verwenden den bestätigten Bootstrap-
Commit und dessen Version; sie wechseln nicht unbemerkt auf einen neueren Stand.
Destroy, Replace, Import, Target-/Variablen-Overrides und zusätzliche Actions
werden vor der Bestätigung abgelehnt. Sicherheits-/Policy-Prüfungen werden nicht
übersprungen. Ein No-op-Plan benötigt keinen Apply.

## Tests und Grenzen dieser Abnahme

```bash
python scripts/project_bootstrap.py check
python scripts/check_landing_zone.py
python scripts/check_repository.py --base origin/main
python scripts/check_project_abc_compatibility.py --base 9cc6a509f958ebc9b3fdf8406f1a8e25a502784c
python scripts/export_provider_schema.py --refresh --check
python scripts/run_secret_scan.py --gitleaks /pfad/zu/gitleaks --base origin/main
```

Alle neuen TFE-Ressourcen werden ausschließlich mit Mock-Providern getestet.
Ein zustandsbehafteter Test führt einen lokalen Mock-Apply und einen zweiten
JSON-geprüften Plan aus: alle Bootstrap-Objekte und Outputs müssen No-op sein.
Synthetische API-Fixtures prüfen Fehler, Versionsbindung, explizite Freigaben,
fremde IDs, verbotene Operationen und Drift. Kein Test startet einen echten
HCP-Bootstrap, Workspace-Create oder SAP-Apply. Bestehende HCP-Workspaces werden
abschließend lesend auf unveränderte Einstellungen und States geprüft.
Live-Einrichtung und Live-Validierung der neuen Plattform bleiben bis zu einem
gesonderten Auftrag offen. Testzahlen und commitbezogene CI-Nachweise stehen im PR.

Primärquellen der gepinnten Versionen:
[TFE Workspace](https://github.com/hashicorp/terraform-provider-tfe/blob/v0.83.0/website/docs/r/workspace.html.markdown),
[Workspace Settings](https://github.com/hashicorp/terraform-provider-tfe/blob/v0.83.0/website/docs/r/workspace_settings.html.markdown),
[Team Access](https://github.com/hashicorp/terraform-provider-tfe/blob/v0.83.0/website/docs/r/team_access.html.markdown),
[Variable-Set-Anbindung](https://github.com/hashicorp/terraform-provider-tfe/blob/v0.83.0/website/docs/r/workspace_variable_set.html.markdown),
[Runs-API](https://developer.hashicorp.com/terraform/cloud-docs/api-docs/run),
[BTP-Authentifizierung](https://github.com/SAP/terraform-provider-btp/blob/v1.27.0/docs/index.md),
[CF-Authentifizierung](https://github.com/cloudfoundry/terraform-provider-cloudfoundry/blob/v1.18.0/docs/index.md).
