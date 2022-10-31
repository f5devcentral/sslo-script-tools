# SSL Orchestrator Script Tools

This repository contains a set of script tools useful in SSL Orchestrator deployments.

- **Internal Layered Architecture**: Contains an iRule implementation to create a layered SSL Orchestrator configuration, to reduce complexity by treating topologies as (semi)static functions.

- **SNI Switching**: Contains a set of iRules useful in inbound topologies to dynamically select a client SSL profile based on incoming TLS Client Hello SNI value.

- **Nuke Delete**: A small script useful in completely destroying a failed/corrupted SSL Orchestrator deployment. Note that this will erase all Guided Configuration objects, including any Access Guided Config settings.

- **Misc Tools**: Miscellaneous script tools.

- **SSLOFIX**: BIG-IP SSL Orchestrator control plane diagnostic, synchronization, and repair tool.

- **SaaS Tenant Isolation**: A simple iRule to inject SaaS tenant isolation headers for Office365, Webex, Google G-Suite, Dropbox, Youtube, and Slack.

