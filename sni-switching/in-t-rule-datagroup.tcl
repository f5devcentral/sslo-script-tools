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
	SSL::disable
    TCP::collect
}
when CLIENT_DATA priority 250 {
	binary scan [TCP::payload] cSS tls_xacttype tls_version tls_recordlen
	set tls_length [expr $tls_recordlen+5]
	if { ([info exists tls_length]) } {
		if { [TCP::payload length] < $tls_length } {
			TCP::collect
			return
		}
    }
    ## call the external procedure
    set sni [call library-rule::getSNI [TCP::payload]]
    ##log local0. "select sni is $sni"

    if { ${sni} eq "null" } {
            set cmd "SSL::disable" ; eval $cmd
			set cmd "SSL::disable serverside" ; eval $cmd
    } else {
       ## lookup SSL profile in data group
       set sslprofile [class match -value ${sni} ends_with sni-switching-dg]
       ##log local0. "select profile is $sslprofile"
       if { ${sslprofile} ne "" } {
		  SSL::enable
          set cmd "SSL::profile /Common/${sslprofile}" ; eval $cmd
          #log local0. "SSL profile changed to $sslprofile"
       }

    }
    TCP::release
}
