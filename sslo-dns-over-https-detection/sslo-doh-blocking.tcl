## Rule: SSL Orchestrator DNS-over-HTTPS detection and blocking
## Author: Kevin Stewart
## Version: 1, 1/2021
## Function: Creates a mechanism to detect and block DNS-over-HTTPS requests through an SSL Orchestrator outbound topology.
## Instructions: 
##  - Under Local Traffic -> iRules in the BIG-IP UI, import the required iRule.
##  - In the SSL Orchestrator UI, under the Interception Rules tab, click on the interception rule to edit (typically ending with "-in-t"), and at the bottom of this configuration page, add the iRule and then (re)deploy.
when HTTP_REQUEST priority 750 {
    if { ( [HTTP::method] equals "GET" and [HTTP::header exists "accept"] and [HTTP::header "accept"] equals "application/dns-json" ) or \
         ( [HTTP::method] equals "GET" and [HTTP::header exists "accept"] and [HTTP::header "accept"] equals "application/dns-message" ) or \
         ( [HTTP::method] equals "POST" and [HTTP::header exists "content-type"] and [HTTP::header "content-type"] equals "application/dns-message" ) } {        
         reject
    }
}
