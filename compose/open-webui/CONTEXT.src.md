# Open WebUI — Local Context Source
<!-- ctx:node id="dbf13d04-e686-4cda-9434-c439e23bb400" version="0.1.0-draft" -->

## Parent Context Node

<!-- contextcanon-placement-parent:start -->
- [Application runtimes](..) — `0.1.0-draft`
  <!-- ctx:parent id="90dd976e-8753-495b-a631-d708b13878d1" version="0.1.0-draft" normalized-digest="74bf1306d7da7225f485ed9a63938259e2af53be41f451024d1af47fc430d7c2" package-digest="558e628e517fabe47987e789a2117c390ffca6e69df4574311775692abd324be" -->
<!-- contextcanon-placement-parent:end -->

## Local Overview

<!-- contextcanon-placement-overview:start -->
<!-- cc:placement-overview id="ONB-15284536311B" -->
- Open WebUI runs as a persistent Docker service accessed from the Windows browser through WSL localhost forwarding.

<!-- cc:placement-overview id="ONB-57A446045BBD" -->
- Open WebUI reaches configured model providers over the network.
<!-- contextcanon-placement-overview:end -->

## Local State

<!-- contextcanon-placement-state:start -->
<!-- cc:placement-state id="ONB-9745CD6E1E1C" -->
- The default Open WebUI address is `http://localhost:3000`.

<!-- cc:placement-state id="ONB-35A21B57D6C3" -->
- Open WebUI stores its persistent state in a named Docker volume.

<!-- cc:placement-state id="ONB-725C7FD86EA6" -->
- The first Open WebUI account becomes the local administrator.
<!-- contextcanon-placement-state:end -->

## Local Rules

<!-- contextcanon-placement-rules:start -->
### Onboarding placement

- **Open WebUI binds to localhost:** Open WebUI binds only to `127.0.0.1` on the WSL host by default.
  Why: Keeps the browser service off LAN-facing interfaces unless an operator deliberately adds stronger controls.
  <!-- ctx:rule id="ONB-055DC22CD3AD" -->

- **Open WebUI receives no host workspace:** Open WebUI receives no host workspace.
  Why: Prevents the service from gaining direct access to host project files.
  <!-- ctx:rule id="ONB-5CC56E3A7A35" -->

- **Open WebUI receives no Docker socket:** Open WebUI receives no Docker socket.
  Why: Prevents the web application from controlling the Docker daemon.
  <!-- ctx:rule id="ONB-84AA72A87719" -->

- **Open WebUI keeps authentication enabled:** Open WebUI keeps authentication enabled.
  Why: Maintains an authenticated boundary even while the service is localhost-only.
  <!-- ctx:rule id="ONB-DEF73E20EAE8" -->

- **Use a strong Open WebUI administrator password:** Use a strong password for the Open WebUI administrator account.
  Why: The first local account has administrator authority over the service.
  <!-- ctx:rule id="ONB-EAAB7BB9AD74" -->

- **Do not expose Open WebUI without added controls:** Do not publish the Open WebUI localhost port through a proxy or LAN interface without appropriate TLS, authentication and network controls.
  Why: Localhost binding is the default safety boundary; broader exposure requires compensating controls.
  <!-- ctx:rule id="ONB-4D2A3FDC8A51" -->
<!-- contextcanon-placement-rules:end -->
