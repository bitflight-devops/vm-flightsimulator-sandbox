# vm-flightsimulator-sandbox

A two-VM scenario harness for verifying the [vm-blackbox Claude Code plugin](https://github.com/bitflight-devops/vm-flightsimulator).

See [PLAN.md](./PLAN.md) for the full milestone plan, constants, and verification checklist.

This scenario is designed to be orchestrated by the vm-blackbox Claude Code plugin.

## VMs

- **ubuntu** (`192.168.56.10`) — Ubuntu 22.04 server hosting PostgreSQL 16 and the `petpoll` database.
- **windows** (`192.168.56.11`) — Windows Server 2022 hosting Eclipse Temurin 21, Apache Tomcat 10.1, and the `petpoll` Spring Boot web application on port 8595.
