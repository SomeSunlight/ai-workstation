# NemoClaw, Hermes und rootless Podman

**Status:** experimenteller Referenz-Installer. Diese Dokumentation beschreibt den *gewählten* Open-Source-Stack. Ein End-to-End-Lauf mit Hermes/OpenRouter unter WSL2 wurde noch **nicht** erfolgreich verifiziert. Die Dateien dieses Branches sind nicht mit dem Docker-Test aus PR #76 vermischt.

## Architektur und Verantwortlichkeiten

Der neue Stack besteht aus **Ubuntu 26.04.1 LTS**, **rootless Podman 5.7** aus den signierten Ubuntu-Paketquellen, **NemoClaw** (Originalinstaller, gepinnter Git-Commit), **OpenShell** (Sicherheit) und **Hermes** (Agent), zunächst über **OpenRouter** (Cloud-Inferenz). Auf Windows läuft Ubuntu in einer einzelnen WSL2-Distribution. Auf einem privaten Linux-System gilt derselbe Linux-/Ansible-Prozess, ohne Docker Desktop und ohne Windows-Sonderkonfiguration.

AI-Workstation erstellt lediglich die Linux-Arbeitsstation. NemoClaw verwaltet anschliessend OpenShell-Gateway, Images, Hermes, Netzwerkregeln, Credentials und Agentensessions. Die AIW installiert **keine zweite Agentenverwaltung**, keine CUDA-Treiber und kein NVIDIA Container Toolkit. Die Projektdateien und das kanonische Wissen liegen in **Markdown/Git**, unabhängig von Hermes. Geschäftliche und private Daten und API-Zugangsdaten werden niemals automatisch synchronisiert.

### Warum nicht Docker Engine unter WSL?

Der Versuch aus [PR #76](https://github.com/SomeSunlight/ai-workstation/pull/76) und [Issue #77](https://github.com/SomeSunlight/ai-workstation/issues/77) belegte, dass der Docker-Stack zwar technisch lief, **NemoClaw 0.0.144 aber ausdrücklich `Native Docker Engine inside WSL is not the qualified Docker Desktop integration` meldete**. Selbst `nemohermes onboard --no-gpu` beseitigte diesen Plattformblocker nicht. Die Toolkit-/CDI-Empfehlung war ein sekundärer Hinweis. Keine CUDA-Installation oder Änderung der OpenShell-Policies beseitigt diese Sperre.

NVIDIA bietet rootless Podman als ausdrücklich auswählbaren alternativen Provider für qualifizierte Linux/WSL-Konstellationen an. Der Upstream verlangt **Podman >=5** samt aktivem current-user Socket, systemd-Userdienst, cgroups v2, Bridge/DNS, Netavark und `lsof`. Ubuntu 24.04 hat offiziell Podman 4.9; Ubuntu 26.04 hat **5.7**. Wir nutzen keine externen Podman-Paketquellen. **Einschränkung:** NVIDIAs WSL-Podman-Qualifikation richtet sich besonders auf WSL-lokales Ollama. Hermes + OpenRouter unter WSL bleibt für unser Setup ein zu bestätigender Durchstich.

Referenzen:
- [NVIDIA Hermes: Voraussetzungen](https://docs.nvidia.com/nemoclaw/user-guide/hermes/get-started/prerequisites)
- [NVIDIA: Podman-Fehlerbehebung](https://docs.nvidia.com/nemoclaw/user-guide/hermes/reference/troubleshooting)
- [NVIDIA: unterstützte Plattformen](https://docs.nvidia.com/nemoclaw/user-guide/hermes/reference/platform-support)
- [Podman: offizieller rootless systemd-Socket](https://docs.podman.io/en/latest/markdown/podman-system-service.1.html)
- [Ubuntu: Paket Podman 5.7](https://packages.ubuntu.com/resolute/podman)
- [Microsoft: offizielle WSL-Images und SHA256](https://github.com/microsoft/WSL/blob/master/distributions/DistributionInfo.json)

## Windows / WSL2: Installation und Betrieb

**Quelle:** Branch `feat/77-nemoclaw-podman-wsl` von `SomeSunlight/ai-workstation`. Der Basis-Branch ist `main`, **nicht** der vorherige Docker-PR-Branch.

Das erste Docker-Experiment wird absichtlich separat entfernt. Vor dem Löschen müssen keine NemoClaw- oder Docker-Artefakte migriert werden, sofern dort noch keine eigenen Daten abgelegt wurden. Das Skript `bootstrap/windows/Remove-OldNemoWsl.ps1` bietet `Status` und, mit ausdrücklicher Bestätigung, `Remove`. Es akzeptiert die bekannten Ubuntu-Testversionen **24.04 und 26.04**, verweigert die Löschung bei anderen Ubuntu-Versionen, abweichender Installationsstelle oder fehlender AIW-Eigentumsmarkierung. Die erkannte Ubuntu-Version wird vor der endgültigen Bestätigung angezeigt. **`wsl --unregister` löscht die ganze alte Distribution dauerhaft**, samt Images und Volumes; nicht die anderen beiden Linux-Installationen. Es entfernt danach nur eindeutig identifizierte alte NemoClaw-Verknüpfungen; verbliebene Dateien am alten Ort werden *nicht* pauschal gelöscht.

Der Windows-Einstieg bleibt `install-nemoclaw.ps1`. Standardziel ist wieder `AIW-Nemo` in `C:\WSL\AIW-Nemo`, nachdem die alte Testdistribution entfernt wurde. Installationsarbeiten sind nachvollziehbar im Git-Branch und der zentralen `config/versions.json`: das neue Ubuntu-26.04.1-WSL-Image ist auf SHA256 `48d56724b5c8e60f24893e83e73bbb58c60b3ca22fba3da977075420acd54104` gepinnt; die bestehenden Ubuntu-24.04/Docker-Versionen bleiben unverändert.

Der Windows-Installer importiert nur die gewählte neue Distribution und meldet beim längeren WSL-Image-Import periodisch den Status. Danach werden Linux-Benutzer, systemd und das Git-Checkout erstellt. Das Profil `nemoclaw-podman` führt den Linux-Ansible-Installer aus. Er nutzt das bestehende auf Python 3.12/uv gesperrte Automationsprojekt; die Ubuntu-26-System-Python-Version bleibt unverändert. Ansible installiert rootless Podman 5.7, aktiviert und prüft den aktuellen Benutzer-Socket und installiert NemoClaws *eigenen* Hermes-CLI-Installer **mit `NEMOCLAW_GATEWAY_RUNTIME=podman`**. Ubuntu 24.04, Docker Engine, Desktop und die bisherigen WSL-Distributionen bleiben ausserhalb dieses Ablaufs.

Anschliessend bietet AIW den **offiziellen** `nemohermes onboard --no-gpu`-Assistenten an. Wähle OpenRouter und gib den Schlüssel nur im Upstream-Assistenten ein. Eine unterbrochene Installation wird durch denselben AIW-Installer fortgesetzt, ohne eigene Reparaturbefehle oder automatische Löschung von Agentenstatus. Der Windows-NemoClaw-Pinguin öffnet dasselbe schmale CLI-Menü.

Wichtig: WSL-Distributionen teilen sich einen Kernel und teilweise Netzwerkressourcen; sie sind keine vollständig voneinander getrennten VMs. Die OpenShell-Sandbox und NemoClaws Policy sind davon verschiedene Sicherheitsmechanismen. Docker Desktop wird nicht installiert.

## Native Linux-/Privatinstallation

Das eigentliche Linux-Profil ist `./install.sh install --yes --profile nemoclaw-podman`. Es benötigt Ubuntu 26.04 mit systemd und `uv`-Bootstrap (vom Installer verwaltet); es enthält **keine** Windows-/WSL-API. Die Architektur bleibt identisch, Daten und Credentials jedoch strikt auf dem jeweiligen Rechner.

Ausdrücklich nicht unterstützt ist ein automatisches In-place-Upgrade bestehender Ubuntu-24.04-Distributionen. Solange die Plattform noch erprobt wird, ist eine neue separate WSL-Distribution leichter zu prüfen und risikofrei wieder zu verwerfen.

### WSL-Startmeldung über die systemd-Benutzersitzung

Beim ersten Ubuntu-26.04-Import und Benutzerwechsel kann WSL die Meldung `Failed to start the systemd user session for 'moresunlight'` ausgeben, obwohl der Linux-Befehl zur Benutzerabfrage erfolgreich ist. Der ursprüngliche Windows-Installer mischte Standardausgabe und Fehlermeldung (`2>&1`) und prüfte nur die erste Zeile; deshalb wurde die WSL-Meldung fälschlich als angeblicher Benutzername ausgegeben. Der Installer liest nun die **tatsächliche Standardbenutzeridentität** über `wsl.exe --exec /usr/bin/id -un` von **stdout**, hält stderr separat in einem Diagnoseprotokoll fest und meldet eine systemd-Benutzersitzungswarnung ausdrücklich als **anderes Problem**.

Das ist keine allgemeine Entwarnung: **rootless Podman braucht einen funktionsfähigen systemd-Benutzermanager und dessen Socket**. Unsere Ansible-Rolle aktiviert `linger`, startet den Benutzermanager und prüft die rootless Podman-API. Misslingt das, muss die konkrete WSL/systemd-Konstellation diagnostiziert werden, statt Benutzer neu anzulegen, WSL global herunterzufahren oder Podman mit sudo zu starten. Microsoft dokumentiert ähnliche WSL-Fehler mit mehreren Distributionen, z. B. in [microsoft/WSL #40593](https://github.com/microsoft/WSL/issues/40593) und [#13826](https://github.com/microsoft/WSL/issues/13826). Die tatsächliche Ursache beim einzelnen Host ist noch **nicht bestätigt**.

Die normale Wiederaufnahme nach dem behobenen Benutzerprüffehler ist ein **erneuter Aufruf von `install-nemoclaw.ps1`** im aktualisierten Branch: die bereits angelegte Ubuntu-Distribution und der Benutzer bleiben erhalten. Keine Neuinstallation und keine Löschung notwendig.

## Diagnose und Nachweise

Die **GitHub-Actions-Tests** prüfen Bash-Syntax, Python-Verträge, Ansible-Lint/-Syntax, Windows-PowerShell-Parsen/Installationslogik und alte Regressionen, verändern aber keinen Besitzerrechner. Die eigentliche Abnahme ist zunächst ein Durchstich: Podman-Rootless-Socket erreichbar, NemoClaw-Preflight akzeptiert WSL, Hermes-Sandbox erstellt, OpenRouter antwortet, ein Markdown-/Git-Projekt ist bearbeitbar. Das Ergebnis wird mit kurzer, datenschutzbereinigter Fehlerbeschreibung in [Issue #77](https://github.com/SomeSunlight/ai-workstation/issues/77) festgehalten.

Die frühere Abkreuz-Checkliste wird **nicht** in diesen neuen Zweig übernommen. Nach erfolgreichem ersten Durchstich folgt eine zweite, spätere Installation als Reproduzierbarkeitsnachweis. Der Nutzer muss nicht dieselben Schritte zweimal durchspielen.

## Repository-Grenze

Langfristig liegen Linux-Ansible, Podman, NemoClaw und der Linux-CLI-Einstieg in einem eigenen Repo `ai-workstation-linux`. Windows-Import, Hostdienste und ein dünner Starter bleiben in `ai-workstation`. Der Windows-Teil verwendet später einen **gepinnten Linux-Git-Commit** und ein stabiles `install/verify/status`-Interface – nicht mehr denselben Branch-Namen. Bis zur Erstellung des neuen Repos bleibt der neue Profilpfad auf diesem separaten Branch versioniert. Siehe [Repository-Aufteilung](architecture-repo-split.md) und [Issue #78](https://github.com/SomeSunlight/ai-workstation/issues/78).
