# F5 SSL Orchestrator SNI Switching iRules
A set of iRules useful in SSL Orchestrator inbound gateway mode topologies to dynamically select a client SSL profile based on incoming SNI in TLS Client Hello.

### Current version:
1.0.0

### Version support
This utility works on BIG-IP 14.1 and above, SSL Orchestrator 5.x and above.

### How to install 
- Import the library-rule to the BIG-IP. Name it 'library-rule'.

- Import either the static or data groups in-t-rule iRule. Its name is arbitrary. 

- If selecting the static version, SNI to client SSL profile matching is done directly in the iRule code. Any manipulation of the SNI-to-profile matching is managed directly in the iRule.

- If selecting the data group version, SNI to client SSL profile matching is done in a data group. Create a string data group (SNI-value := client-ssl-profile-name). Reference this data group in the iRule. Any manipulation of the SNI-to-profile matching is managed directly in the data group.

- Edit the corresponding inbound topology Interception Rule and add the static or datagroup iRule. Deploy and test.
