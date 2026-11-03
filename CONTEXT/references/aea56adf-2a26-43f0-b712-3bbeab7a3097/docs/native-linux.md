# Native Ubuntu 24.04 — experimental host installation

> **Status: Issue #33 implementation candidate.** The AI Workstation's Linux entry
> points and Ansible roles are reused for Ubuntu 24.04 on bare metal or a normal
> VM. **A complete native-host installation is not yet owner-tested or accepted.**
> Production Windows 11 + WSL2 remains the accepted setup.

## Supported assumptions for the first native-host experiment

- Ubuntu **24.04**, **x86-64**, booted with **systemd as PID 1**.
- An ordinary, non-root user with `sudo` and a usable sudo **password**.
  The current installer explicitly prompts for that password; passwordless-only
  cloud images are not covered by this first slice.
- Native Ubuntu filesystem, checked-out Git repository owned by that user,
  and working network/package repositories.
- Docker Engine will be installed by the project's pinned Ansible role.
  This modifies system packages and configures/enables Docker and containerd.
  Start with a disposable Ubuntu VM, **not** an irreplaceable shared host.
- No GPU is required. Local inference is optional; Goose/Open WebUI may use an
  external API provider instead. Intel SYCL automatic setup remains **WSL-only**.
- Ordinary GPU-pod containers (even with CUDA) are not equivalent to an Ubuntu
  host with systemd/sudo and are **not** in this acceptance contract.

## Candidate install procedure on a disposable native Ubuntu system

From a normal Ubuntu user session:

```bash
sudo -v
git clone https://github.com/SomeSunlight/ai-workstation.git
cd ai-workstation

./install.sh status
./install.sh install
aiw status
aiw verify
```

The first `status` checks the supported OS/systemd assumptions without
installing packages. The full `install` asks for confirmation and sudo
credentials, bootstraps the pinned Python/uv/Ansible environment, and executes
Ansible's host/Docker roles. `verify` checks the installed host.

**To test this PR before merging**, check out its review branch in a throwaway
checkout. Normal `main` will not contain these changes until the owner accepts
the PR. Do not run a second full installer just to review CLI text or tests.

To check Linux/WSL platform behavior *without* installing anything, run:

```bash
bash tests/smoke/host-platform.sh
aiw status
```

The host is displayed as `wsl` or `native-linux`. On WSL the repository
still must not be under `/mnt/*`; on native Ubuntu, normal Linux-mounted
storage at `/mnt/data` is allowed, subject to ordinary ownership and mode
checks. Keeping the Git checkout on a native POSIX filesystem is recommended.

## Browser access on a native host

`aiw open-webui open` starts or checks Open WebUI, then:
- opens a Windows browser from WSL if available;
- opens `xdg-open` on native Ubuntu **only when a graphical session is present**;
- prints the loopback URL on headless native Ubuntu, without pretending the
  remote VM has a browser.

On a remote native machine, `http://localhost:3000` refers to **that
machine**, not your laptop. For a private SSH tunnel to the default port:

```bash
ssh -L 3000:127.0.0.1:3000 USER@YOUR-UBUNTU-HOST
```

Keep that SSH session open and visit `http://localhost:3000` on your
**own** computer. Adapt the port if you configured a non-default WebUI port.
Avoid exposing Open WebUI or an inference endpoint directly to the public
internet without deliberate authentication/TLS/firewall design.

After joining the `docker` group for the first time, **log out and log in**
to refresh your user's group membership. On WSL, the existing Windows/WSL
restart instructions remain valid; native Ubuntu does not need a WSL restart.

## Honest acceptance boundary

GitHub Ubuntu CI validates shell behavior and Ansible syntax, not the host
installer end to end. For native-host acceptance we still need to observe:
a clean host install, a second idempotent install, `aiw status/verify`,
Goose's real container and workspace isolation, Open WebUI's loopback access,
non-destructive updates, and any recoverable failures. Mark the platform
supported in official Context and STATE **only after this is accepted**.

The separate external engine process manager is tracked by
[AI Workstation #34](https://github.com/SomeSunlight/ai-workstation/issues/34).
Strata/CUDA GPU hosting and provider-account billing are out of scope here.
