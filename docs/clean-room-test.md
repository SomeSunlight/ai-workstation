# Clean-room test

Keep the working distribution as a reference and create a second distribution
with a separate registered name, filesystem and storage directory. WSL
distributions still share the Windows WSL platform, kernel, global `.wslconfig`
and the overall WSL 2 resource limit. Do not run heavy workloads in both during
the installation test.

From an elevated PowerShell 7 terminal in the Windows checkout:

```powershell
.\install.ps1 `
  -DistroName Ubuntu-24.04-Test `
  -InstallLocation C:\WSL\Ubuntu-24.04-Test
```

The installer refuses to overwrite or unregister an existing distribution. It
may update the shared WSL platform and merge the global `.wslconfig`, but it does
not change the reference distribution's Linux filesystem. If custom distribution
names are unsupported, it stops before creating the test distribution.

After the test succeeds:

```powershell
wsl -d Ubuntu-24.04-Test
```

Inside Linux:

```bash
aiw status
aiw verify
```
