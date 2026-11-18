# Architekturentscheid: Windows-Bootstrap und Linux-Workstation trennen

**Entscheidung:** zwei Repositories mit eigener Verantwortung und unabhängigem Release-Takt. Nicht nur zwei Verzeichnisse, die weiterhin jede Änderung gemeinsam testen müssen.

**Praxisstand (16. November 2026):** Der erste **NemoClaw + Hermes + OpenShell + rootless-Podman-Durchstich** unter `AIW-Nemo` ist **erfolgreich installiert und per Inferenz-Smoke-Test verifiziert**: Sandbox `testsandbox01`, Hermes-Gateway, OpenRouter und Tavily. Damit ist die Voraussetzung für eine **konkrete Extraktion des Linux-Teils** grundsätzlich erfüllt. Ein frei formulierter Agenten-/Datei-Test, die Migration zum bestehenden Dispatcher ([Issue #80](https://github.com/SomeSunlight/ai-workstation/issues/80)) und die zweite Hardware-Installation fehlen noch. Der Status von Nvidia Ubuntu-26.04-Hostqualifikation bleibt experimentell. Nachweise: [Hermes-Operator-Guide](nemoclaw-operator.md) und [Issue #77](https://github.com/SomeSunlight/ai-workstation/issues/77).

## Verantwortungsgrenze

| Repository | Aufgabe | Betrieb |
|---|---|---|
| `SomeSunlight/ai-workstation` (bestehend) | Windows-Host-Software wie Llama Dispatcher/Process Compose und ggf. WSL-Import, Windows-Shortcut, Windows-Sicherheit/DPAPI. Es **startet** Linux, aber kennt keine Agentensandbox-Semantik. | Windows 11 |
| `SomeSunlight/ai-workstation-linux` (vom Eigentümer später anzulegen) | Ansible für Ubuntu, rootless Podman, gepinntes NemoClaw, Hermes-Einstieg, CLI-Tools, offene Markdown-/Git-Konventionen, native Linux-Installation und Verification. Es kennt **keine** Windows-/WSL-spezifischen APIs. | Ubuntu Linux, nativ oder WSL2 |

**Schnittstelle:** Windows importiert eine Distribution aus einer überprüften Ubuntu-Imageversion und ruft einen versionierten Linux-Installer auf, der nur die Befehle `install`, `verify`, `status` als stabile öffentliche Oberfläche anbietet. Das Windows-Projekt pinnt eine bestimmte Linux-Revision in einer eigenen Versionsdatei. Linux-Konfiguration und private Dokumente sind keine Daten des Windows-Hostprojekts.

## Migration ohne monolithischen PR

Der Test für [Issue #77](https://github.com/SomeSunlight/ai-workstation/issues/77) ist absichtlich ein **unabhängiger Branch von `main`**. Er verwendet den vorhandenen Windows-Bootstrap und ein neues Ansible-Profil, ohne die Docker-Experiment-Historie aus [PR #76](https://github.com/SomeSunlight/ai-workstation/pull/76) zu übernehmen.

1. **Erreicht:** Podman-/Hermes-/OpenShell-Installation mit echter OpenRouter-Inferenz erfolgreich durchgeführt, ohne zuvor neue GitHub-Repo-Berechtigungen vorauszusetzen. Der konkrete Agenten-Tool-Test bleibt ein separater kurzer Betriebsnachweis.
2. Nach Erfolg legt der Benutzer das neue **öffentliche oder private Repository** `ai-workstation-linux` selbst an. Die Wahl der Sichtbarkeit und Zugriffsrechte bleibt seine Entscheidung.
3. Linux-Teile einschliesslich ihrer eigenen `uv.lock`-, Python-/Ansible-Pins, GitHub-Actions und Dokumentation als eigenständig installierbares Projekt extrahieren. Kein Git-Submodul, kein automatischer Statusabgleich mit dem Windows-Branch.
4. Windows-Bootstrap auf einen expliziten Linux-Git-Commit umstellen und lediglich den Vertrag `install/verify/status` prüfen. Die Linux-CI testet NemoClaw/Podman; die Windows-CI testet WSL/DPAPI/Windows. Beide Projekte benötigen keine gemeinsamen CI-Jobs.
5. Erst nach erfolgreicher Installation mit dieser Aufteilung Legacy-Code und alte Docker-Draft-PRs schliessen. Weder das neue Repo noch der Split dürfen WSL-Images oder Daten automatisch löschen.

**Nicht tun:** Den bestehenden Windows-Dispatcher durch NemoClaw ersetzen, Docker Desktop als Abkürzung installieren, privat/geschäftlich synchronisieren, oder das gesamte Linux-Repository als Git-Submodul im Windows-Repo verstecken. Das würde die gerade zu beseitigende Kopplung wiederherstellen.

Nach diesem Split muss eine Änderung an einer Linux-Agentenpolicy **nicht** die Windows-Hostdienste und ihre Benutzerführung neu qualifizieren.

## Umsetzung freigegeben – 18. November 2026

Der Benutzer hat die eigentliche Auftrennung von Windows-AIW und Linux-AIW jetzt freigegeben. Eine erneute Hermes-Installation ist als **optionale, erst nach verifiziertem Backup** auszuführende Migration zulässig; es besteht keine Freigabe für sofortiges `destroy`, `rebuild`, WSL-Neuimport oder Änderungen am Dispatcher auf Speedy. Das live getestete `testhermes01` bleibt zunächst erhalten.

**Konkreter Migrationsvertrag:** [Linux repository handoff](linux-repository-handoff.md). Dort sind Eigentümerschaft, unabhängige Release-Versionen, das immutable Git-Pin zwischen beiden Projekten, der native-Ubuntu-Vertrag, die Dateiabgrenzung und die nachweisorientierten Migrationsstufen festgelegt.

**Beobachteter Defekt im Altzustand:** Ein `git pull` im Windows-Checkout aktualisiert nicht `/home/<linux-user>/ai-workstation` innerhalb von `AIW-Nemo`. Die Windows-Verknüpfung ruft den separaten Linux-Checkout auf. Dadurch zeigte der aktualisierte Shortcut am 18. November noch ein altes Menü. Das ist keine NemoClaw-Störung, sondern eine fehlende Versions-/Release-Grenze. Nach dem Split vergleichen wir nicht länger Windows- und Linux-Branches, sondern zeigen ihre **unabhängigen Git-Identitäten** an; Windows pinnt einen geprüften Linux-Commit.

Der neue Eigentümer-Repo-Name bleibt `SomeSunlight/ai-workstation-linux`. Erst wenn dieses vom Benutzer angelegt ist, erfolgt die echte Extraktion auf dessen eigenem Branch; nicht durch Kopieren des gesamten Monorepos oder durch einen weiteren Linux-Daemon innerhalb des Windows-Repos. Draft PR #84 bleibt der abgeschlossene, separate Hermes-Operator-Fix und wird nicht automatisch gemergt.
