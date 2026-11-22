# NemoClaw/Hermes: erster Betrieb und Test auf AIW-Nemo

**Status (16. November 2026):** Der erste reale Owner-Durchstich ist gelungen. Die vorhandene WSL-Distribution `AIW-Nemo` mit Ubuntu 26.04.1 LTS, rootless Podman 5.7, OpenShell und dem unveränderten upstream **NemoClaw für Hermes** ist installiert. Die Sandbox **`testsandbox01`** wurde angelegt, Hermes-Gateway und Inferenz-Smoke-Test waren erfolgreich. Ein interaktiver, vom Nutzer formulierter Agentenauftrag mit Dateioperationen steht **noch aus**. Das ist der letzte Unterschied zwischen *fertig eingerichtet* und *praktisch erprobt*.

> **Supportgrenze:** NVIDIAs NemoClaw-Preflight meldete Ubuntu 26.04 als **noch nicht für Host-Onboarding qualifiziert** (Warnung). Die offiziellen Container-/Netzwerkprüfungen haben trotzdem bestanden. Das ist ein erfolgreich getesteter Referenzpfad, **keine** Behauptung einer vollständigen NVIDIA-Plattformzertifizierung. Keine Upstream-Policies oder Sicherheitsprüfungen wurden ausgeschaltet.

## Tatsächlich bewiesene Installation

Die Linux-Umgebung lief mit Microsoft WSL **3.0.5.0** (Kernel **6.18.58.1-1**) nach einem bewussten, hostweiten WSL-Update; frühere WSL 2.7.14.0 hatte einen bekannten Multi-Distro-systemd/cgroup-Konflikt. Rootless Podman **5.7.0** bestand cgroups-v2-, Netz-, DNS- und Socket-Prüfungen, einschliesslich des realen `podman --remote info`. Der Installer bestätigte den gepinnten Vendor-Stand **`nemohermes v0.0.144`** / **`82e1ad7474ec7175c5b860b2bfa9d7940bc6e75f`**.

Über den **offiziellen interaktiven** NemoClaw-Onboarder wurden eingerichtet:

| Eigenschaft | Ergebnis des ersten echten Laufs |
| --- | --- |
| Sandbox | `testsandbox01`, **erstellt** und bereit |
| Agent | Hermes, Gateway-Health **bestanden** |
| Inferenz | OpenRouter, `deepseek/deepseek-v4.1-flash-1017`; Host- und Inferenz-Smoke **bestanden** |
| Credential-Grenze | Registrierung beim OpenShell-Gateway, nicht im AIW-Repo oder Agentenprompt |
| Suchfunktion | Tavily aktiviert, **Egress aus der Sandbox nachweislich verifiziert** |
| Netzwerkpolicy | **Balanced**; vom NVIDIA-Assistenten verwaltete Presets für u. a. npm, PyPI, Hugging Face, Homebrew, Tavily und WhatsApp |
| Ressourcen | **developer**, 75 % CPU / 75 % RAM als ausgewählte Sandbox-Grenze |
| Messaging | WhatsApp `self-chat` konfiguriert; **QR-Pairing noch nicht nachgewiesen** |
| GPU | Kein GPU-Passthrough (`--no-gpu`), Cloud-Inferenz benötigt es nicht |

Das eingeblendete Modell `deepseek-ai/deepseek-v4.1-flash` aus NVIDIAs *Featured Catalog* gab beim OpenRouter-Probe HTTP 400 zurück. Erfolgreich validiert und verwendet wurde dagegen die **manuell eingetragene** OpenRouter-Modellkennung `deepseek/deepseek-v4.1-flash-1017`. Das beweist **keinen** API-Key-Fehler oder OpenShell-Egress-Fehler: Der Host validiert das Modell bereits **vor** der Sandbox-Konfiguration.

### Zuständigkeiten

```text
Windows / AIW: WSL-Import, Ubuntu, Version-Pins, Installationsaufruf
    └── Ubuntu AIW-Nemo: rootless Podman + offizielles NemoClaw
         └── OpenShell: Gateway, Policy, Credentials, Sandbox
              └── Hermes in testsandbox01: Agent, Tools, Dateien
                   └── OpenShell-verwaltete Inferenz → OpenRouter (aktuell)
```

AIW betreibt **keine eigene Session-, Container-, Provider-, Modell- oder Policy-Verwaltung** über diesem Stack. Für tägliche Bedienung, Providerwechsel, Backup/Snapshot, Logs und Agentenstart hat NemoClaw bereits native Kommandos. Der alte Docker/Goose-Stack bleibt als **separate Legacy-Option** unberührt, solange seine Ablösung nicht ausdrücklich beschlossen und unter realer Arbeit verifiziert wurde.

## Neustart, Stop und Fehlerbehebung (aktualisierter Praxisbefund)

Die [Hermes-Recovery-Anleitung](nemoclaw-recovery.md) dokumentiert den aktuellen Betreiberstand vom 18. November 2026: neue Sandbox `testhermes01` mit lokalem Dispatcher, konkrete Crash-/Rebuild-Probleme, tägliches Starten/Stoppen, Port-Forwarding-Recovery, Rückbaugrenzen und die Wiederherstellung des vorhandenen Windows-Pinguins. **Für alltägliche Bedienung immer diese aktuelle Anleitung verwenden**; die ursprünglichen `testsandbox01`/OpenRouter-Schritte unten sind die historische Erstinstallation.

## Der erste echte Hermes-Test

**Einfachster Einstieg:** Unter Windows den Desktop-Pinguin **NemoClaw Hermes (AIW-Nemo)** öffnen. Im angezeigten AIW-Menü `4) Connect to my Hermes sandbox` wählen und als Namen **`testsandbox01`** eingeben. Damit öffnet NemoClaw eine Shell *innerhalb* dieser Sandbox. Dort:

```bash
hermes
```

Alternativ in Windows-PowerShell die bestehende WSL-Distribution öffnen und den *offiziellen* NemoClaw-Launcher ausführen (kein Neuinstallieren):

```powershell
wsl -d AIW-Nemo --user moresunlight
```

```bash
export PATH="$HOME/.local/bin:$PATH"
export NEMOCLAW_GATEWAY_RUNTIME=podman
nemohermes testsandbox01 status
nemohermes launch testsandbox01
```

**Erster Prompt** (in Hermes, keine Dateinamen auf Windows-Seite nötig):

> Erstelle innerhalb deiner Sandbox eine Datei `/tmp/aiw-hermes-smoke.txt` mit drei Zeilen über deine verfügbaren Arbeitswerkzeuge. Lies die Datei anschliessend wieder ein und gib ihren tatsächlichen Inhalt aus. Erkläre kurz, welche Werkzeuge du verwendet hast.

Das prüft *Modellantwort + Hermes-Tool-Aufruf + Dateisystemzugriff + Rücklesen*. Eine reine Chat-Antwort ohne ausgeführten Datei-Lesevorgang wäre **kein** bestandener Agententest. Danach als zweite, getrennte Probe: eine kurze Tavily-Recherche mit Quelle; die vorhandene Ansible-/NemoClaw-Probe hat die **Netzfreigabe**, nicht die Qualität jeder späteren Websuche bewiesen.

**Status und Logs** (in Ubuntu, ausserhalb der Sandbox):

```bash
nemohermes testsandbox01 status
nemohermes testsandbox01 logs --follow
nemohermes inference get
```

Um den Browser-Dashboard-Link **vom offiziellen CLI** anzeigen zu lassen:

```bash
nemohermes testsandbox01 dashboard-url --quiet
```

Der Installationslog nennt `127.0.0.1:18789` (Dashboard) und `127.0.0.1:8642/v1` (Hermes OpenAI-kompatible API), aber ausdrücklich nur **nach aktivierter, authentifizierter Portweiterleitung**. Keine Portfreigabe ins öffentliche Netz. Das Gateway-Token `nemohermes testsandbox01 gateway-token --quiet` ist ein **Geheimnis**, nicht in Terminalprotokollen, Issues, Git oder Screenshots veröffentlichen. WhatsApp wurde nur konfiguriert; QR-Pairing ist ein optionaler gesonderter Vorgang. Für den ersten Agententest **nicht nötig**.

Die verwendeten Policies erlaubten einige zusätzliche Paket-/Messaging-Domains, teilweise auch TLS-Ausnahmen; das entspricht den vom Nutzer gewählten **offiziellen** Presets, nicht automatisch einem minimalen Sicherheitsprofil. Wenn npm, Brew oder WhatsApp in einem konkreten Agentenprojekt nicht gebraucht werden, die Presets später über **NemoClaws Policy-Bedienung** reduzieren, nicht in AIW doppelt nachbauen.

## Als Nächstes: vom OpenRouter-Modell zum Llama Dispatcher

Der bereits produktiv verwendete **Llama Dispatcher** auf Speedy bietet über die bestehende **Caddy-HTTPS-Strecke** `https://somesunlight.duckdns.org/v1` eine OpenAI-kompatible Schnittstelle mit den Modell-Aliasen **`agent`** (Tool-/Ausführungstätigkeiten) und **`sparringpartner`** (Reasoning). Diese Aliase zeigen derzeit auf denselben extern betriebenen Strata-Modellprozess; **AIW-Nemo darf weder eine zweite Strata-Instanz starten noch dessen Betrieb übernehmen**.

Der offizielle, im gepinnten NVIDIA-Commit dokumentierte Hermes-Wechsel erfolgt über `nemohermes inference set`: **Provider `compatible-endpoint`**, `--model agent`, `--endpoint-url https://somesunlight.duckdns.org/v1`, `--inference-api openai-completions`, `--sandbox testsandbox01`, und ein *eigener* zeitweise sicher bereitgestellter `COMPATIBLE_API_KEY` für den neuen Dispatcher-Client. NemoClaw kann den Endpoint-Provider registrieren und die OpenShell-Providerbindung, den Sandbox-Route-Record und **`/sandbox/.hermes/config.yaml`** koordiniert anpassen. **Darum kein manuelles YAML-Editieren als normale Migrationsstrategie.** Die API ist vom Ubuntu-Host aus über HTTPS zu prüfen; in der Sandbox darf nur die vom OpenShell-Provider genehmigte Inferenzverbindung entstehen. Private-IP-/DNS-Pin- und Netzwerk-Policies **nicht umgehen**.

Bei einem Providerwechsel kann NemoClaw für Hermes das Gateway kurz neu starten. Der bisherige OpenRouter-Pfad bleibt als nachvollziehbarer Rückfall erhalten; zuerst einen echten Datei-/Tool-Agentenlauf unter OpenRouter als Referenz nachweisen. Die vollständige, auth-sichere Migration steht in [Issue #80](https://github.com/SomeSunlight/ai-workstation/issues/80), nicht im Windows-Installer.

**Offizielle Quellen:** [Hermes Quickstart](https://docs.nvidia.com/nemoclaw/user-guide/hermes/get-started/quickstart), [Switch Providers](https://docs.nvidia.com/nemoclaw/user-guide/hermes/inference/manage-inference/switch-providers), [Custom OpenAI-compatible endpoints](https://docs.nvidia.com/nemoclaw/user-guide/hermes/inference/custom-endpoints/set-up-openai-compatible-endpoint).

## Referenzinstallation versus spätere Portabilität

Dieser Owner-Durchstich belegt **eine** funktionierende Installation auf einem vorhandenen Windows/WSL-Laptop. Eine zweite unabhängige Installation (z. B. native Ubuntu-Maschine oder anderer Laptop) ist noch nicht erfolgt. Die vom Nutzer gewünschte Trennung [Windows-Host `ai-workstation` / Linux-Agent `ai-workstation-linux`](architecture-repo-split.md) ist nach dem Erfolg eine **konkrete nächste Architekturarbeit**, nicht mehr reine Vorstudie; siehe [Issue #78](https://github.com/SomeSunlight/ai-workstation/issues/78). Keine zweite Benutzeroberfläche und keine künstliche Agentenverwaltung aufbauen.
