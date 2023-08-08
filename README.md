# SSL Orchestrator Script Tools

This repository contains a set of script tools useful in SSL Orchestrator deployments.

- **Internal Layered Architecture**: Contains an iRule implementation to create a layered SSL Orchestrator configuration, to reduce complexity by treating topologies as (semi)static functions.

- **SNI Switching**: Contains a set of iRules useful in inbound topologies to dynamically select a client SSL profile based on incoming TLS Client Hello SNI value.

- **SaaS Tenant Isolation**: Contains an iRule to enable tenant isolation (aka tenant restrictions) for multiple SaaS providers (Office365, Webex, Google, Dropbox, Youtube, and Slack).

- **DNS over HTTPS (DoH and DoT) Detection**: Contains a set of tools for the detection and management of DoH and DoT traffic.

- **Generative AI Categories**: Contains an installation script and a list of known generative AI tools. The installation script is used to install a custom URL category on the BIG-IP for use in SSL Orchestrator policy, to detect and manage generative AI traffic.

- **Nuke Delete**: A small script useful in completely destroying a failed/corrupted SSL Orchestrator deployment. Note that this will erase all Guided Configuration objects, including any Access Guided Config settings.

- **Misc Tools**: Miscellaneous script tools.

- **SSLOFIX**: BIG-IP SSL Orchestrator control plane diagnostic, synchronization, and repair tool.

