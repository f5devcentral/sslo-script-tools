# F5 SSL Orchestrator Nuclear Delete Script
A small Bash utility to completely remove all SSL Orchestrator configurations and objects.

[![Releases](https://img.shields.io/github/v/release/kevingstewart/sslo_nuke_delete.svg)](https://github.com/kevingstewart/sslo_nuke_delete/releases)

### Version support
This utility works on BIG-IP 14.1 and above, SSL Orchestrator 5.x and above.

### How to install 
- Download the script onto the F5 BIG-IP:

  `curl -k https://raw.githubusercontent.com/kevingstewart/sslo_nuke_delete/main/sslo_nuke_delete.sh -o sslo_nuke_delete.sh`
  
  `chmod +x sslo_nuke_delete.sh`
  
  `./sslo_nuke_delete.sh`

- Run the script more than once if any errors are returned.
