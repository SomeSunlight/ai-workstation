# Architecture

The workstation separates Windows/WSL handling, minimal Linux bootstrap, Ansible host configuration, container image/runtime definitions, and the `aiw` operator interface. The repository—not manually drifted hosts or running containers—is the installation specification. Maintained layer responsibilities and invariants are in [Project Context](../CONTEXT.md).
