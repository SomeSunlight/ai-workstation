# NemoClaw, Hermes und rootless Podman

**Status (16. November 2026): erster realer WSL-/Hermes-Referenz-Durchstich erfolgreich.** Ubuntu 26.04.1, rootless Podman, OpenShell-Gateway, `testsandbox01`-Sandbox, Hermes-Gateway und ein echter OpenRouter-Inferenz-Smoke-Test wurden erfolgreich verifiziert. Das Navi-/Tool-/Datei-Szenario mit einem frei formulierten Hermes-Prompt, eine zweite Maschineninstallation und die Verbindung mit dem lokalen Dispatcher sind **noch nicht** verifiziert. NVIDIA warnte, dass Ubuntu 26.04 als Host-Release noch nicht offiziell qualifiziert ist; sämtliche tatsächlich ausgeführten Vendor-Prüfungen wurden bestanden. Die Dateien dieses Branches sind weiterhin von der Docker-Testhistorie in PR #76 getrennt. **Betrieb und nächster Praxistest:** [Hermes-Betriebsanleitung](nemoclaw-operator.md).

## Architektur und Verantwortlichkeiten

Der neue Stack besteht aus **Ubuntu 26.04.1 LTS**, **rootless Podman 5.7** aus den signierten Ubuntu-Paketquellen, **NemoClaw** (Originalinstaller, gepinnter Git-Commit), **OpenShell** (Sicherheit) und **Hermes** (Agent), zunächst über **OpenRouter** (Cloud-Inferenz). Auf Windows läuft Ubuntu in einer einzelnen WSL2-Distribution. Auf einem privaten Linux-System gilt derselbe Linux-/Ansible-Prozess, ohne Docker Desktop und ohne Windows-Sonderkonfiguration.

AI-Workstation erstellt lediglich die Linux-Arbeitsstation. NemoClaw verwaltet anschliessend OpenShell-Gateway, Images, Hermes, Netzwerkregeln, Credentials und Agentensessions. Die AIW installiert **keine zweite Agentenverwaltung**, keine CUDA-Treiber und kein NVIDIA Container Toolkit. Die Projektdateien und das kanonische Wissen liegen in **Markdown/Git**, unabhängig von Hermes. Geschäftliche und private Daten und API-Zugangsdaten werden niemals automatisch synchronisiert.

### Warum nicht Docker Engine unter WSL?

Der Versuch aus [PR #76](https://github.com/SomeSunlight/ai-workstation/pull/76) und [Issue #77](https://github.com/SomeSunlight/ai-workstation/issues/77) belegte, dass der Docker-Stack zwar technisch lief, **NemoClaw 0.0.144 aber ausdrücklich `Native Docker Engine inside WSL is not the qualified Docker Desktop integration` meldete**. Selbst `nemohermes onboard --no-gpu` beseitigte diesen Plattformblocker nicht. Die Toolkit-/CDI-Empfehlung war ein sekundärer Hinweis. Keine CUDA-Installation oder Änderung der OpenShell-Policies beseitigt diese Sperre.

NVIDIA bietet rootless Podman als ausdrücklich auswählbaren alternativen Provider für qualifizierte Linux/WSL-Konstellationen an. Der Upstream verlangt **Podman >=5** samt aktivem current-user Socket, systemd-Userdienst, cgroups v2, Bridge/DNS, Netavark und `lsof`. Ubuntu 24.04 hat offiziell Podman 4.9; Ubuntu 26.04 hat **5.7**. Wir nutzen keine externen Podman-Paketquellen. **Bewährter Befund:** Der Hermes/OpenRouter-Durchstich auf unserem WSL-Laptop ist mittlerweile real erfolgreich: Rootless-Podman-Socket, OpenShell-Gateway, OpenRouter-Modellprüfung, Sandbox-Erstellung und Hermes-Gateway wurden geprüft. Die **formale NVIDIA-Qualifikation von Ubuntu 26.04 als Host** fehlt laut eigener Upstream-Preflight-Warnung dennoch. Ein erfolgreicher Praxislauf ist nicht gleichbedeutend mit einer Plattformfreigabe.

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

Anschliessend bietet AIW den **offiziellen** `nemohermes onboard --no-gpu`-Assistenten an. Dort wurden **OpenRouter**, das Modell `deepseek/deepseek-v4.1-flash-1017`, der `developer`-Ressourcenmodus und `Balanced`-Policies erfolgreich eingerichtet. Das von NVIDIAs dynamischem Katalog angebotene `deepseek-ai/deepseek-v4.1-flash` scheiterte dagegen mit **HTTP 400**; dies war keine OpenShell-Policy-Sperre, denn der Host validiert Modellnamen **vor** dem Sandbox-Aufbau. Die gültige Modellkennung wurde im **Other**-Dialog des Upstream-Onboarders eingegeben. Zugangsdaten ausschliesslich im offiziellen Assistenten, nicht in AIW/Git. Eine unterbrochene **Host**-Installation lässt sich idempotent wiederaufnehmen; `--resume` von **NemoClaw** benötigt dagegen einen bereits angelegten NemoClaw-Onboarding-Zustand (sonst ist **New** richtig). Der Windows-Pinguin öffnet das schmale CLI-Menü. Siehe [Live-Befund und erste Agententests](nemoclaw-operator.md).

Wichtig: WSL-Distributionen teilen sich einen Kernel und teilweise Netzwerkressourcen; sie sind keine vollständig voneinander getrennten VMs. Die OpenShell-Sandbox und NemoClaws Policy sind davon verschiedene Sicherheitsmechanismen. Docker Desktop wird nicht installiert.

## Native Linux-/Privatinstallation

Das eigentliche Linux-Profil ist `./install.sh install --yes --profile nemoclaw-podman`. Es benötigt Ubuntu 26.04 mit systemd und `uv`-Bootstrap (vom Installer verwaltet); es enthält **keine** Windows-/WSL-API. Die Architektur bleibt identisch, Daten und Credentials jedoch strikt auf dem jeweiligen Rechner.

Ausdrücklich nicht unterstützt ist ein automatisches In-place-Upgrade bestehender Ubuntu-24.04-Distributionen. Solange die Plattform noch erprobt wird, ist eine neue separate WSL-Distribution leichter zu prüfen und risikofrei wieder zu verwerfen.

### WSL-Startmeldung über die systemd-Benutzersitzung

Beim ersten Ubuntu-26.04-Import und Benutzerwechsel kann WSL die Meldung `Failed to start the systemd user session for 'moresunlight'` ausgeben, obwohl der Linux-Befehl zur Benutzerabfrage erfolgreich ist. Der ursprüngliche Windows-Installer mischte Standardausgabe und Fehlermeldung (`2>&1`) und prüfte nur die erste Zeile; deshalb wurde die WSL-Meldung fälschlich als angeblicher Benutzername ausgegeben. Der Installer liest nun die **tatsächliche Standardbenutzeridentität** über `wsl.exe --exec /usr/bin/id -un` von **stdout**, hält stderr separat in einem Diagnoseprotokoll fest und meldet eine systemd-Benutzersitzungswarnung ausdrücklich als **anderes Problem**.

Das ist keine allgemeine Entwarnung: **rootless Podman braucht einen funktionsfähigen systemd-Benutzermanager und dessen Socket**. Unsere Ansible-Rolle aktiviert `linger`, startet den Benutzermanager und prüft die rootless Podman-API. Misslingt das, muss die konkrete WSL/systemd-Konstellation diagnostiziert werden, statt Benutzer neu anzulegen, WSL global herunterzufahren oder Podman mit sudo zu starten. Microsoft dokumentiert ähnliche WSL-Fehler mit mehreren Distributionen, z. B. in [microsoft/WSL #40593](https://github.com/microsoft/WSL/issues/40593) und [#13826](https://github.com/microsoft/WSL/issues/13826). Die tatsächliche Ursache beim einzelnen Host ist noch **nicht bestätigt**.

Die normale Wiederaufnahme nach dem behobenen Benutzerprüffehler ist ein **erneuter Aufruf von `install-nemoclaw.ps1`** im aktualisierten Branch: die bereits angelegte Ubuntu-Distribution und der Benutzer bleiben erhalten. Keine Neuinstallation und keine Löschung notwendig.

### Ubuntu 26.04: `sudo-rs` und Ansible `become`

Beim ersten echten Podman-Durchstich unter Ubuntu 26.04.1 wurde das Linux-`sudo`-Passwort erfolgreich angenommen, doch **Ansible 2.21.1** scheiterte noch vor den Podman-Tasks bei `Gathering Facts` mit `Timed out waiting for become success or become password prompt`. Nach einem zweiten Installationslauf trat **derselbe** Fehler auf. Auch Windows-Administratorrechte änderten daran nichts: Windows-UAC und Linux-Ansible-`become` sind getrennte Berechtigungsräume.

**Ursache:** Ubuntu 26.04 verwendet standardmässig das neue `sudo-rs`, dessen Passwortprompt von der gepinnten Ansible-Version nicht zuverlässig erkannt wird. Die Fehlermeldung stimmt mit dem Ubuntu-Bug [LP #2122414](https://bugs.launchpad.net/bugs/2122414) überein. Ubuntu dokumentiert, dass die frühere klassische Variante **`sudo.ws`** weiterhin unterstützt wird: [Ubuntu Server: sudo-rs](https://ubuntu.com/server/docs/reference/other-tools/sudo-rs/).

**AIW-Lösung:** Ausschliesslich das `nemoclaw-podman`-Profil stellt mittels Ubuntus signiertem `sudo`-Paket sicher, dass `/usr/bin/sudo.ws` vorhanden ist, und exportiert **nur für seine Ansible-Unterprozesse** `ANSIBLE_SUDO_EXE=/usr/bin/sudo.ws`. Die systemweite `sudo`-Alternative, die Linux-Sicherheitsrichtlinien und der normale Ubuntu-Standard **bleiben unverändert**. Das Linux-Passwort wird wie bisher einmal interaktiv angenommen und über eine temporäre, nur für den Benutzer lesbare Datei an `ansible-playbook --become-password-file` übergeben, nicht in Git oder eine Prozessargumentliste geschrieben.

Vor dem eigentlichen Podman-Playbook führt AIW jetzt mit *derselben* Ansible-`become`-Konfiguration ein winziges `id -u`-Playbook aus und erwartet die Benutzer-ID `0`. Falls das fehlschlägt, endet die Installation **sofort am Rechte-Preflight**, statt nochmals minutenlang beim Podman-Playbook zu warten. Dies prüft den tatsächlichen Ansible-Mechanismus; ein erfolgreiches `sudo -v` allein hätte diesen Fehler nicht entdeckt.

**Wiederaufnahme:** Den Branch `feat/77-nemoclaw-podman-wsl` aktualisieren und denselben Windows-Einstieg `install-nemoclaw.ps1` erneut ausführen. Die bereits eingerichteten Ubuntu-, Git-, uv- und Ansible-Komponenten bleiben erhalten. Kein Löschen der WSL-Distribution und keine manuelle Änderung von `update-alternatives`.

### WSL systemd `user@1000.service` und parallele Linux-Distributionen

Der vierte reale Laptop-Test konnte den früheren Ansible-/`sudo-rs`-Fehler vollständig überwinden: Das Ansible-`sudo.ws`-Preflight war erfolgreich, Ubuntu 26.04-Pakete und **rootless Podman 5.7** samt Netzwerkabhängigkeiten wurden installiert, Subuid/Subgid waren bereits vorhanden, und `loginctl enable-linger` war erfolgreich. Der **systemd-Benutzermanager `user@1000.service`** startete jedoch nicht. Das ist ein Plattformproblem **vor** dem NemoClaw- und Hermes-Onboarding; es darf nicht durch rootful Podman, Entfernen von cgroup-Policies oder Löschen der Distribution umgangen werden.

Im Microsoft WSL-Issue [#40593](https://github.com/microsoft/WSL/issues/40593) hat ein WSL-Entwickler die zugrunde liegende Kollision erklärt: Mehrere WSL-Distributionen teilten sich Teile derselben cgroup-Hierarchie. Wenn die systemd-Benutzersitzungen gleichzeitig starten, kann `user@1000.service` an `Device or resource busy` scheitern. Unsere frühere WSL-Warnung **und** der Fehlschlag passen exakt zum Symptombild, aber die konkrete Ursache auf dem Laptop ist **noch nicht bestätigt**, solange das Journal fehlt.

Microsoft hat die **per-Distro-cgroup-Isolation** mit [WSL 2.9.8](https://github.com/microsoft/WSL/releases/tag/2.9.8) (24. August 2026, PR [#40519](https://github.com/microsoft/WSL/pull/40519)) veröffentlicht. [WSL 2.9.13](https://github.com/microsoft/WSL/releases/tag/2.9.13) enthält am 25. September eine weitere Korrektur für Distro-cgroup-Namespaces; [WSL 3.0.5](https://github.com/microsoft/WSL/releases/tag/3.0.5) ist am 3. November 2026 erschienen.

**AIW-Entscheid:** Das neue `NemoPodman`-Profil verlangt deshalb **WSL >=2.9.13**, prüft diese Version unmittelbar beim Windows-Installationsstart, und gibt bei zu alter WSL-Version **vor** einem langen Linux-Installationslauf eine begründete Fehlermeldung aus. Es führt **kein** `wsl --update` aus, da die WSL-Version die **anderen** vorhandenen Distributionen und ihren Betrieb mitbetrifft. Ein Upgrade der offiziellen Microsoft-WSL-Installation muss der Besitzer bewusst freigeben und auf mögliche Auswirkungen auf seine bisherigen Linux- und OpenShell-Umgebungen prüfen. `wsl.exe --version` kann ohne Administratorrechte und ohne Änderung ausgeführt werden.

Falls das Problem auf einer ausreichend neuen WSL-Version dennoch besteht, dokumentiert die Ansible-Rolle bei gescheitertem `user@UID.service` künftig **automatisch** den `systemctl show`-Status und einen begrenzten `journalctl -b -u user@UID.service`-Auszug (30 Zeilen) im lokalen Installationslog. Der konkrete Befund entscheidet über die nächste Korrektur. **Keine automatische UID-Änderung, keine Beendigung anderer Distributionen, keine systemweite WSL-Konfigurationsänderung, keine unsichere Root-Podman-Ausweichlösung.**

Die aktuelle `AIW-Nemo`-Distribution und alle erfolgreich installierten Komponenten sind zu behalten; die Installation läuft nach Erfüllung der WSL-Voraussetzung idempotent weiter.

## Diagnose und Nachweise

Die **GitHub-Actions-Tests** prüfen Bash-Syntax, Python-Verträge, Ansible-Lint/-Syntax, Windows-PowerShell-Parsen/Installationslogik und alte Regressionen, verändern aber keinen Besitzerrechner. Der **reale Owner-Durchstich ist gelungen**: WSL 3.0.5, Ubuntu 26.04.1, rootless Podman 5.7, NemoClaw `v0.0.144`, OpenShell-Gateway, Sandbox `testsandbox01`, Hermes-Gateway, OpenRouter-Inferenz und Tavily-Egress. Die beiden NemoClaw-Playbooks meldeten **34 erfolgreiche Tasks ohne Fehler** und **19 Verifikations-Tasks ohne Fehler**; Vendor-Onboarding bestätigte `Deployment verified` und `Hermes is ready`. Vorherige Fehler, darunter `sudo-rs`-/Ansible-Prompt, WSL-Multi-Distro-cgroups und eine leere PowerShell-stderr-Datei, wurden auf ihren jeweiligen Ebenen behoben. **Noch offen:** frei formulierter Hermes-Tool-/Datei-End-to-End-Auftrag, späterer Dispatcher-Modellwechsel und der Reproduzierbarkeitstest auf einer zweiten Maschine. Befunde und Ursachen sind in [Issue #77](https://github.com/SomeSunlight/ai-workstation/issues/77) erfasst; Bedienung und erster Praxistest in [nemoclaw-operator.md](nemoclaw-operator.md).

Die frühere Abkreuz-Checkliste wird **nicht** in diesen neuen Zweig übernommen. Der **erste Durchstich ist erfolgreich**. Die spätere zweite Installation auf anderer Hardware ist der noch offene Reproduzierbarkeitsnachweis; kein Grund, den Benutzer dieselbe Installation sofort erneut durchspielen zu lassen. Für tägliche Verwaltung sind die **offiziellen** NemoClaw-Kommandos zuständig. Der Wechsel zu unserem bestehenden Llama Dispatcher ist das separate [Issue #80](https://github.com/SomeSunlight/ai-workstation/issues/80).

## Repository-Grenze

Langfristig liegen Linux-Ansible, Podman, NemoClaw und der Linux-CLI-Einstieg in einem eigenen Repo `ai-workstation-linux`. Windows-Import, Hostdienste und ein dünner Starter bleiben in `ai-workstation`. Der Windows-Teil verwendet später einen **gepinnten Linux-Git-Commit** und ein stabiles `install/verify/status`-Interface – nicht mehr denselben Branch-Namen. Bis zur Erstellung des neuen Repos bleibt der neue Profilpfad auf diesem separaten Branch versioniert. Siehe [Repository-Aufteilung](architecture-repo-split.md) und [Issue #78](https://github.com/SomeSunlight/ai-workstation/issues/78).
