## SSLO SNI Switching Rule (static version)
## Author: Kevin Stewart
## Date: July 2020
## Purpose: Useful in SSLO versions 8.x and below to switch the client SSL profile based on ClientHello SNI
##      in inbound SSLO topologies. This would be practical for L3 inbound gateway mode or L2 inbound topologies.
## Instructions: 
##      - Import server certificates and private keys
##      - Create a separate client SSL profile for each cert/key pair
##      - Add the library-rule iRule to LTM (name "library-rule")
##      - Add the SNI-switching-rule to LTM (name is arbitrary)
##      - Create an L3 inbound gateway (or L2 inbound) mode SSLO topology. Define a server cert/key to be used as the "default" (when no SNI matches)
##      - Edit the corresponding Interception Rule and add the SNI switching rule. 
##      - Edit this iRule to select the correct client SSL profile based on the SNI. Deploy and test.

when CLIENT_ACCEPTED priority 250 {
    TCP::collect
}
when CLIENT_DATA priority 250 {
    ## call the external procedure
    set sni [call library-rule::getSNI [TCP::payload]]    

    switch [string tolower ${sni}] {
        "foo.f5labs.local" {
            set cmd1 "SSL::profile /Common/test1-clientssl" ; eval $cmd1
        }
        "bar.f5labs.local" {
            set cmd2 "SSL::profile /Common/test2-clientssl" ; eval $cmd2
        }
        "blah.f5labs.local" {
            set cmd3 "SSL::profile /Common/test3-clientssl" ; eval $cmd3
        }
    }
    TCP::release
}
