# Patch 0.4.7

Fix Linux host installation when started from the Windows installer.

Ansible playbooks use `become: true`. A prior `sudo -v` was not enough for
Ansible in this execution path, so the Linux installer now asks once for the
Linux sudo password and passes it to Ansible via a temporary
`--become-password-file`.

The temporary file is removed automatically on exit.
