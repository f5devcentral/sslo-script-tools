# F5 SSL Orchestrator sslofix script

The SSLOFIX script is used to diagnose and repair control plane errors and inconsistencies in SSL Orchestrator deployments. 

Future versions of the script will be included in BIG-IP releases and will not require this installation procedure.

### Current version:

1.0.10

### Version support
This utility works on BIG-IP 15.1 and above, SSL Orchestrator 7.x and above.

### How to install 
- Download the script onto the F5 BIG-IP:

  `cd ~`
  
  `curl -k https://raw.githubusercontent.com/f5devcentral/sslo-script-tools/main/sslofix/sslofix -o sslofix`
  
  `chmod +x sslofix`
  
### Usage Instructions

Full instructions are available in the [SSLO Troubleshooting Guide](https://clouddocs.f5.com/sslo-troubleshooting-guide/main/sslofix.html).