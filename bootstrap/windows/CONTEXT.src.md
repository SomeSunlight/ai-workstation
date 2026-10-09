# Windows and WSL bootstrap — Local Context Source
<!-- ctx:node id="a46c5141-dcdf-4f28-9839-4053a02e04cf" name="Windows and WSL bootstrap" version="0.1.2-draft" -->

## Parent Context Node

<!-- contextcanon-placement-parent:start -->
- [Bootstrap](..) — `0.1.2-draft`
  <!-- ctx:parent id="f78265e4-e023-4d7a-9b26-9a917ef68a4a" version="0.1.2-draft" normalized-digest="a5acfe9353cd48188dafb8149a9b0401aca7415e9c1accc53ef2be907976828f" package-digest="956857de1196cada340f3d64f467cb6fa123e9b34ea93558b3959dcd13d1cbc9" -->
<!-- contextcanon-placement-parent:end -->

## Local Overview

<!-- contextcanon-placement-overview:start -->
<!-- cc:placement-overview id="ONB-824062AB56E8" -->
- PowerShell owns Windows, WSL, reboot continuation and distribution lifecycle.
<!-- contextcanon-placement-overview:end -->

## Local Rules

<!-- contextcanon-placement-rules:start -->
### Onboarding placement

- **Existing WSL distributions are never removed:** Existing WSL distributions are never unregistered or deleted automatically.
  Why: Protects existing Linux environments while allowing the installer to be rerun or used for clean-room testing.
  <!-- ctx:rule id="ONB-DE918FE55390" -->
<!-- contextcanon-placement-rules:end -->

## Local Topics

<!-- contextcanon-placement-topics:start -->
### Clean-room WSL test procedure

When testing installation in a separate WSL distribution or rerunning the clean-room reinstall procedure, read the clean-room test guide.

Required:
- Resource: `../../docs/clean-room-test.md`

<!-- ctx:topic id="ONB-CF243F7DFF6C" -->
<!-- contextcanon-placement-topics:end -->
