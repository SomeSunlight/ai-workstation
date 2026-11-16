# Architekturentscheid: Windows-Bootstrap und Linux-Workstation trennen

**Entscheidung:** zwei Repositories mit eigener Verantwortung und unabhängigem Release-Takt. Nicht nur zwei Verzeichnisse, die weiterhin jede Änderung gemeinsam testen müssen.

## Verantwortungsgrenze

| Repository | Aufgabe | Betrieb |
|---|---|---|
| `SomeSunlight/ai-workstation` (bestehend) | Windows-Host-Software wie Llama Dispatcher/Process Compose und ggf. WSL-Import, Windows-Shortcut, Windows-Sicherheit/DPAPI. Es **startet** Linux, aber kennt keine Agentensandbox-Semantik. | Windows 11 |
| `SomeSunlight/ai-workstation-linux` (vom Eigentümer später anzulegen) | Ansible für Ubuntu, rootless Podman, gepinntes NemoClaw, Hermes-Einstieg, CLI-Tools, offene Markdown-/Git-Konventionen, native Linux-Installation und Verification. Es kennt **keine** Windows-/WSL-spezifischen APIs. | Ubuntu Linux, nativ oder WSL2 |

**Schnittstelle:** Windows importiert eine Distribution aus einer überprüften Ubuntu-Imageversion und ruft einen versionierten Linux-Installer auf, der nur die Befehle `install`, `verify`, `status` als stabile öffentliche Oberfläche anbietet. Das Windows-Projekt pinnt eine bestimmte Linux-Revision in einer eigenen Versionsdatei. Linux-Konfiguration und private Dokumente sind keine Daten des Windows-Hostprojekts.

## Migration ohne monolithischen PR

Der Test für [Issue #77](https://github.com/SomeSunlight/ai-workstation/issues/77) ist absichtlich ein **unabhängiger Branch von `main`**. Er verwendet den vorhandenen Windows-Bootstrap und ein neues Ansible-Profil, ohne die Docker-Experiment-Historie aus [PR #76](https://github.com/SomeSunlight/ai-workstation/pull/76) zu übernehmen.

1. Den Podman-/Hermes-Durchstich durchführen, ohne vorher eine neue GitHub-Repo-Berechtigungsstruktur vorauszusetzen.
2. Nach Erfolg legt der Benutzer das neue **öffentliche oder private Repository** `ai-workstation-linux` selbst an. Die Wahl der Sichtbarkeit und Zugriffsrechte bleibt seine Entscheidung.
3. Linux-Teile einschliesslich ihrer eigenen `uv.lock`-, Python-/Ansible-Pins, GitHub-Actions und Dokumentation als eigenständig installierbares Projekt extrahieren. Kein Git-Submodul, kein automatischer Statusabgleich mit dem Windows-Branch.
4. Windows-Bootstrap auf einen expliziten Linux-Git-Commit umstellen und lediglich den Vertrag `install/verify/status` prüfen. Die Linux-CI testet NemoClaw/Podman; die Windows-CI testet WSL/DPAPI/Windows. Beide Projekte benötigen keine gemeinsamen CI-Jobs.
5. Erst nach erfolgreicher Installation mit dieser Aufteilung Legacy-Code und alte Docker-Draft-PRs schliessen. Weder das neue Repo noch der Split dürfen WSL-Images oder Daten automatisch löschen.

**Nicht tun:** Den bestehenden Windows-Dispatcher durch NemoClaw ersetzen, Docker Desktop als Abkürzung installieren, privat/geschäftlich synchronisieren, oder das gesamte Linux-Repository als Git-Submodul im Windows-Repo verstecken. Das würde die gerade zu beseitigende Kopplung wiederherstellen.

Nach diesem Split muss eine Änderung an einer Linux-Agentenpolicy **nicht** die Windows-Hostdienste und ihre Benutzerführung neu qualifizieren.
