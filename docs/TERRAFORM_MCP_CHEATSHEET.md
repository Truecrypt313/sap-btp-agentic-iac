# HashiCorp Terraform MCP – Cheat Sheet (56 Tools)

**Stand: 06.11.2026 · Bezogen auf die 56 Tools, die Codex in deiner laufenden Verbindung zu `https://mcp.terraform.io/mcp` gemeldet hat.**
**Projektkontext:** `sap-ai-landing-zone` mit `sap-btp-core` und `sap-cloudfoundry` · VS Code mit OpenAI Codex · HCP Terraform (Remote Execution).

> **Wichtig:** Die nachfolgenden Bezeichnungen sind **MCP-Toolnamen**, keine Befehle, die du direkt im Linux-Terminal ausführst. In **Codex in VS Code** reicht normalerweise eine normale deutschsprachige Anweisung, ggf. mit dem exakten Toolnamen. Intern kann Codex beispielsweise `mcp__terraform__list_runs` verwenden.
>
> Die tatsächlichen Eingabeparameter jedes Tools zeigt Codex anhand des vom Server bereitgestellten Tool-Schemas an. Die Liste ist ein Funktions-/Prompt-Cheat-Sheet, **keine** erfundene vollständige API-Parameterreferenz.

## Schnellzugriff

| Ziel | Tool | Beispielauftrag an Codex |
|---|---|---|
| Verbindung prüfen | `whoami` | „Prüfe über Terraform MCP, als welcher HCP-Benutzer du angemeldet bist.“ |
| Organisationen sehen | `list_terraform_orgs` | „Liste meine erreichbaren HCP-Organisationen auf.“ |
| Workspaces auflisten | `list_workspaces` | „Liste alle Workspaces in `sap-ai-landing-zone` auf.“ |
| Workspace prüfen | `get_workspace_details` | „Zeige Details und VCS-Anbindung von `sap-btp-core`.“ |
| Runs auflisten | `list_runs` | „Zeige die letzten fünf Runs in `sap-cloudfoundry`.“ |
| Run auswerten | `get_run_details` | „Erkläre den Status von Run `run-7sbX4yE1ae9eNjtk`.“ |
| Plan untersuchen | `get_plan_json_output` | „Prüfe sämtliche Ressourcenänderungen im JSON-Plan des letzten Runs.“ |
| Plan-only starten | `create_run` | „Starte einen **Plan-Only-Run** für `sap-cloudfoundry`; **kein Apply**.“ |
| State-Historie | `list_state_versions` | „Zeige die letzten State-Versionen von `sap-cloudfoundry`.“ |
| Registry-Doku | `search_provider_docs` | „Suche die aktuelle Dokumentation zur Ressource `btp_subaccount`.“ |

**Tool-Kategorien:** `registry`, `registry-private`, `terraform` (HCP Terraform). Die Serverversion und angebotenen Tools können sich ändern.

## Vollständige Toolliste deiner Sitzung

**Kennzeichnung:** „Lesen“ = keine beabsichtigte Änderung in HCP; „Schreiben“ = kann Einstellungen, Variablen, Zugriffe oder Runs verändern; „vertraulich“ = Ergebnisse können sensible Infrastrukturinformationen enthalten. Schreibaktionen benötigen passende HCP-Berechtigungen und ggf. Freigaben im Client. Das Vorhandensein eines Tools allein beweist nicht, dass das Konto dafür berechtigt ist.

### 01 · Öffentliche Terraform Registry (9 Tools)

| Toolname | Funktion | Art |
|---|---|---|
| `get_latest_module_version` | Neueste veröffentlichte Version eines Moduls ermitteln. | Lesen |
| `get_latest_provider_version` | Aktuellste Provider-Version ermitteln. | Lesen |
| `get_module_details` | Dokumentation und Eingabe-/Ausgabevariablen eines Moduls laden. | Lesen |
| `get_policy_details` | Dokumentation einer öffentlichen Sentinel-Policy anzeigen. | Lesen |
| `get_provider_capabilities` | Ressourcen und Data Sources eines Providers erkunden. | Lesen |
| `get_provider_details` | Detaildokumentation eines Providers bzw. Bestandteils abrufen. | Lesen |
| `search_modules` | Öffentliche Terraform-Module suchen. | Lesen |
| `search_policies` | Öffentliche Sentinel-Policies suchen. | Lesen |
| `search_provider_docs` | Terraform-Provider-Dokumentation durchsuchen. | Lesen |

### 02 · Private Registry (4 Tools)

| Toolname | Funktion | Art |
|---|---|---|
| `get_private_module_details` | Details eines privaten Moduls abrufen. | Lesen |
| `get_private_provider_details` | Details eines privaten Providers abrufen. | Lesen |
| `search_private_modules` | Private Module in berechtigten HCP-Organisationen suchen. | Lesen |
| `search_private_providers` | Private Provider in berechtigten HCP-Organisationen suchen. | Lesen |

### 03 · Benutzer und Organisation (3 Tools)

| Toolname | Funktion | Art |
|---|---|---|
| `whoami` | Authentifizierte HCP-Identität und Kontotyp auslesen. | Lesen |
| `get_token_permissions` | Berechtigungen des verwendeten API-Tokens prüfen. | Lesen |
| `list_terraform_orgs` | Erreichbare HCP-Terraform-Organisationen auflisten. | Lesen |

### 04 · Projekte (3 Tools)

| Toolname | Funktion | Art |
|---|---|---|
| `create_project` | Ein neues HCP-Terraform-Projekt erstellen. | Schreiben |
| `get_project` | Details eines HCP-Projekts lesen. | Lesen |
| `list_terraform_projects` | Projekte einer Organisation auflisten. | Lesen |

### 05 · Workspaces und Tags (7 Tools)

| Toolname | Funktion | Art |
|---|---|---|
| `create_no_code_workspace` | Workspace aus einem No-Code-Modul erzeugen. | Schreiben |
| `create_workspace` | Neuen HCP-Terraform-Workspace anlegen. | Schreiben |
| `get_workspace_details` | Workspace-Einstellungen und Metadaten anzeigen. | Lesen |
| `list_workspaces` | Workspaces einer Organisation auflisten. | Lesen |
| `update_workspace` | Workspace-Konfiguration ändern; mögliche Auswirkung auf Runs. | Schreiben |
| `create_workspace_tags` | Tags für einen Workspace erstellen bzw. zuweisen. | Schreiben |
| `read_workspace_tags` | Tags eines Workspaces auslesen. | Lesen |

### 06 · Variablen und Variable Sets (9 Tools)

| Toolname | Funktion | Art |
|---|---|---|
| `attach_variable_set_to_workspaces` | Variablenset mit Workspaces verknüpfen. | Schreiben |
| `create_variable_in_variable_set` | Variable in einem Variablenset anlegen. | Schreiben |
| `create_variable_set` | Neues Variablenset erstellen. | Schreiben |
| `create_workspace_variable` | Variable in einem Workspace erstellen. | Schreiben |
| `delete_variable_in_variable_set` | Variable aus einem Variablenset löschen. | Schreiben/Löschen |
| `detach_variable_set_from_workspaces` | Variablenset von Workspaces lösen. | Schreiben |
| `list_variable_sets` | Variablensets auflisten. | Lesen |
| `list_workspace_variables` | Workspace-Variablen und deren Metadaten auflisten. | Lesen – vertraulich |
| `update_workspace_variable` | Vorhandene Workspace-Variable ändern. | Schreiben |

### 07 · Teams und Berechtigungen (5 Tools)

| Toolname | Funktion | Art |
|---|---|---|
| `add_team_member` | Mitglied zu einem Team hinzufügen. | Schreiben |
| `create_team` | Neues Team erstellen. | Schreiben |
| `get_team` | Teamdetails und Berechtigungen abrufen. | Lesen |
| `grant_team_access` | Team Zugriff auf Workspace oder Projekt geben. | Schreiben – IAM |
| `list_teams` | Teams einer Organisation auflisten. | Lesen |

### 08 · Runs, Plans und Applies (9 Tools)

| Toolname | Funktion | Art |
|---|---|---|
| `create_run` | HCP-Terraform-Run anstoßen (z. B. plan_only). | Schreiben/Run |
| `get_apply_details` | Metadaten eines Applies abrufen. | Lesen |
| `get_apply_logs` | Apply-Logs abrufen. | Lesen – vertraulich |
| `get_plan_details` | Plan-Metadaten und Status abfragen. | Lesen |
| `get_plan_json_output` | Strukturiertes Terraform-Plan-JSON lesen. | Lesen – vertraulich |
| `get_plan_logs` | Plan-Logs anzeigen. | Lesen – vertraulich |
| `get_run_comments` | Kommentare eines HCP-Runs auflisten. | Lesen |
| `get_run_details` | Run-Status und Run-Details prüfen. | Lesen |
| `list_runs` | Runs eines Workspaces auflisten. | Lesen |

### 09 · Sentinel und Policy Sets (3 Tools)

| Toolname | Funktion | Art |
|---|---|---|
| `attach_policy_set_to_workspaces` | Policy Set mit einem Workspace verknüpfen. | Schreiben |
| `list_workspace_policy_sets` | Verknüpfte Policy Sets eines Workspaces auflisten. | Lesen |
| `get_sentinel_mock` | Sentinel-Mock-Daten für Policy-Tests abrufen. | Lesen – vertraulich |

### 10 · State und Terraform Stacks (4 Tools)

| Toolname | Funktion | Art |
|---|---|---|
| `get_stack_details` | Details eines Terraform Stacks auslesen. | Lesen |
| `get_state_version` | Metadaten/Details einer State-Version lesen. | Lesen – vertraulich |
| `list_stacks` | Terraform Stacks einer Organisation auflisten. | Lesen |
| `list_state_versions` | Historie der Workspace-State-Versionen auflisten. | Lesen |

## Weitere MCP-Funktionen: Ressourcen statt Tools

Codex meldete zusätzlich **2 MCP-Ressourcen und 1 Template**:

| URI | Inhalt |
|---|---|
| `/terraform/style-guide` | Terraform Style Guide |
| `/terraform/module-development` | Terraform Module Development Guide |
| `/terraform/providers/{namespace}/name/{name}/version/{version}` | Dynamische Provider-Dokumentation |

Diese Ressourcen sind nicht Teil der 56 Tools.

## Kopierfertige Prompts für dein SAP-BTP-Projekt

### 1. Bestandsaufnahme ohne Änderungen

```text
Verwende ausschließlich Terraform MCP.
Organisation: sap-ai-landing-zone.
Liste die Workspaces sap-btp-core und sap-cloudfoundry auf.
Zeige je Workspace den letzten Run, Run-Status, VCS-Branch und Execution Mode.
Verwende nur lesende Tools. Keine Dateien ändern, keine Runs starten.
```

### 2. Terraform-Plan genau untersuchen

```text
Analysiere im Workspace sap-btp-core den neuesten Terraform-Plan über MCP.
Verwende get_plan_details, get_plan_json_output und bei Bedarf get_plan_logs.
Zeige Add/Change/Destroy je Ressource und kennzeichne jede sicherheitsrelevante
IAM- oder Rollenänderung. Werte keine sensiblen Werte im Klartext aus.
Keinen Apply oder neuen Run starten.
```

### 3. Plan-Only-Run erstellen (echte Aktion, kein Apply)

```text
Verwende Terraform MCP und starte im Workspace sap-cloudfoundry
(Organisation sap-ai-landing-zone) genau einen create_run vom Typ plan_only.
Kein Apply, kein Destroy und keine Änderung des Workspaces.
Lies danach Run-ID, Plan-Status, Ressourcen- und Output-Änderungen aus.
```

### 4. Vorhandene Terraform-Konfiguration verbessern – mit GitOps

```text
Prüfe die Terraform-Dateien im Repository sap-btp-agentic-iac.
Schlage für BTP eine sichere Verbesserung vor und nenne zunächst betroffene
Dateien und mögliche Infrastrukturänderungen. Erstelle anschließend nur
nach meiner Freigabe einen Feature-Branch und überprüfbaren Git-Diff.
Kein direkter Plattform-Eingriff, kein Apply/Destroy und kein Merge.
```

### 5. Variables und IAM prüfen

```text
Verwende Terraform MCP in sap-ai-landing-zone.
Prüfe die Workspace-Konfiguration und Variablen-Metadaten von sap-btp-core.
Zeige fehlende Variablen, falsche HCL-Markierungen, potentielle Risiken und
welche Variablen als sensitive markiert sind. Keine Secret-Werte ausgeben,
keine Berechtigungen oder Variablen verändern.
```

### 6. Terraform-State-Verlauf nachweisen

```text
Liste im Workspace sap-cloudfoundry die letzten fünf State-Versionen auf.
Zeige Zeitstempel, State-Version-ID, Terraform-Version und soweit verfügbar
Seriennummer. Vergleiche die State-Versionen vor und nach dem Apply für PR #1.
Keine sensiblen State-Inhalte ausgeben und nichts ändern.
```

### 7. Neue BTP-Ressource planen – noch nicht umsetzen

```text
Ich möchte in SAP BTP Trial einen TEST-Subaccount in Region us10 bereitstellen.
Prüfe zuerst über Terraform MCP den letzten Plan von sap-btp-core und über
Git die bestehende Terraform-Konfiguration. Ermittle, ob TEST bereits geplant
oder vorhanden ist. Beschreibe die exakten Ressourcenänderungen und Risiken.
Noch keinen neuen Run, Git-Commit, Apply oder Destroy ausführen.
```

## `create_run`: wichtige Optionen

Der gehostete Terraform MCP unterstützt diese regulären Run-Typen (je nach Workspace-Berechtigung und Konfiguration):

| Typ | Wirkung |
|---|---|
| `plan_only` | Erstellt ausschließlich einen nicht anwendbaren Prüfplan. **Unsere erste Wahl für Tests.** |
| `plan_and_apply` | Erstellt einen regulären Run; ein Apply kann später freigegeben werden, wenn der Workspace dies verlangt. |
| `refresh_state` | Aktualisiert State-Informationen durch Refresh, ohne verwaltete Ressourcen gezielt neu zu konfigurieren. Kann den State verändern. |
| `allow_empty_apply` | Lässt je nach Run- und Workspace-Konfiguration auch ein Apply ohne geplante Ressourcenänderungen zu. |

**Nicht auf dem von dir verwendeten HashiCorp-hosted Server verfügbar:** `action_run` (direktes Apply/Discard/Cancel via MCP), `delete_project`, `delete_team`, `delete_workspace_safely`, `force_unlock_workspace`. Ebenso sind `auto_approve` und `is_destroy` als zusätzliche `create_run`-Optionen des gehosteten Servers nicht freigegeben. Das gilt für **diesen Remote-MCP-Server**; ein selbst gehosteter Server kann anders konfiguriert werden. Über HCP-Weboberfläche und vorhandene Workflows sind genehmigte Applies weiterhin möglich.

## MCP vs. Terraform CLI vs. Git

| Ebene | Beispiele | Aufgabe |
|---|---|---|
| **MCP-Tools** (in Codex) | `list_workspaces`, `create_run`, `get_plan_logs` | HCP/Registry-API über KI-Agent nutzen |
| **Terraform CLI** (Terminal) | `terraform fmt`, `terraform init`, `terraform validate`, `terraform plan` | HCL prüfen, Provider initialisieren, Pläne auswerten |
| **Git CLI** (Terminal) | `git status`, `git switch -c`, `git add`, `git commit`, `git push` | Terraform-Code versionieren |
| **GitHub** | Pull Request, Review, Squash and Merge | Änderungen vor Übernahme nach `main` kontrollieren |
| **HCP Terraform UI** | Run, Plan, Confirm & Apply, State | Verwaltete Infrastruktur in der Cloud ausführen |

MCP-Tools ersetzen **nicht** die Terraform-CLI oder den VCS-GitOps-Prozess; sie ergänzen diese um eine sichere, modellgesteuerte API-Schnittstelle.

## Hinweise zur Nutzung und Sicherheit

1. Formuliere in Codex **Organisation und Workspace explizit**; der API-Token kann mehrere Organisationen erreichen.
2. Bitte bei Schreibaktionen um **Diff/Plan vor Ausführung** und lasse Apply/Destroy für deinen Projektworkflow bewusst manuell freigeben.
3. `list_workspace_variables`, Plan-JSON/Logs und State-Inhalte können sensible Konfigurationsdaten enthalten. Keine Tokens, Passwörter, `*.tfvars` oder State-Dateien in GitHub committen.
4. Tool-Verfügbarkeit und Tool-Berechtigung sind unterschiedlich: Prüfe bei Zugriffsproblemen `get_token_permissions`.
5. Der **gehostete** Terraform MCP ist laut HashiCorp **Beta**; die Toolliste kann sich ohne lokale Installation ändern.
6. Ein Prompt allein ist keine Berechtigungssperre. Rechte werden durch HCP-Token, Server-Funktionen, Client-Konfiguration und Freigaben begrenzt.

## Dokumentationsquellen

- [HashiCorp – Terraform MCP Server: vollständige Tool-Referenz](https://developer.hashicorp.com/terraform/mcp-server/reference)
- [HashiCorp – Remote MCP Server: unterstützte Tools und Einschränkungen](https://developer.hashicorp.com/terraform/mcp-server/deploy/remote-mcp)
- [HashiCorp – Terraform MCP Server (GitHub)](https://github.com/hashicorp/terraform-mcp-server)

**Quellenstand:** 06.11.2026. Die Anzahl **56** basiert auf der tatsächlich von Codex gemeldeten Toolliste dieser Projektumgebung. Die Funktionsbeschreibungen basieren auf HashiCorps offizieller Referenz; unter anderen Versionen können einzelne Toolnamen abweichen.
