# F5 SSL Orchestrator Nuclear Delete Script
A small Bash utility to completely remove all SSL Orchestrator configurations and objects.

### Current version:
7.0.0

### Version support
This utility works on BIG-IP 14.1 and above, SSL Orchestrator 5.x and above.

### How to install 
- Download the script onto the F5 BIG-IP:

  `curl -k https://raw.githubusercontent.com/f5devcentral/sslo-script-tools/main/sslo-nuke-delete/sslo-nuke-delete.sh -o sslo-nuke-delete.sh`
  
  `chmod +x sslo-nuke-delete.sh`
  
  `./sslo-nuke-delete.sh`

- Run the script more than once if any errors are returned.
