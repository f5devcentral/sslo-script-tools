## SSLO SNI Switching Rule (data group version)
## Author: Kevin Stewart
## Date: July 2020
## Purpose: Useful in SSLO versions 8.x and below to switch the client SSL profile based on ClientHello SNI
##      in inbound SSLO topologies. This would be practical for L3 inbound gateway mode or L2 inbound topologies.
## Instructions: 
##      - Import server certificates and private keys
##      - Create a separate client SSL profile for each cert/key pair
##      - Create a string data group that maps the SNI to the client SSL profile name (ex. foo.f5labs.com := foo-clientssl)
##      - Add the library-rule iRule to LTM (name "library-rule")
##      - Add the SNI-switching-rule to LTM (name is arbitrary)
##      - Create an L3 inbound gateway (or L2 inbound) mode SSLO topology. Define a server cert/key to be used as the "default" (when no SNI matches)
##      - Edit the corresponding Interception Rule and add the SNI switching rule. Deploy and test.

when CLIENT_ACCEPTED priority 250 {
    TCP::collect
}
when CLIENT_DATA priority 250 {
    ## call the external procedure
    set sni [call library-rule::getSNI [TCP::payload]]
    
    ## lookup SSL profile in data group
    set sslprofile [class lookup ${sni} sni-switching-dg]

    if { ${sslprofile} ne "" } {
        set cmd "SSL::profile /Common/${sslprofile}" ; eval $cmd
    }
    TCP::release
}
