when RULE_INIT {
    ## USer-Defined: dynamic egress server-side layered VIP name
    set static::PROXY_CHAIN_VIP "/Common/upstream-proxy-vip"
}


###################################################
######## NO CUSTOMIZATION BELOW THIS LINE #########
###################################################

when CLIENT_ACCEPTED priority 250 {
 ## DYNAMIC EGRESS UPDATE: disable corresponding -in-t event - the following otherwise mimics the original -in-t iRule except for necessary changes
 event disable

 sharedvar SNI
 sharedvar SEND_SNI
 if { [info exists SNI] } {
    set SEND_SNI ${SNI}
 }

 ## DYNAMIC EGRESS UPDATE: get the SSLO topology name
 set APP [findstr [virtual name] "/Common/sslo_" 13 ".app"]

 ## DYNAMIC EGRESS UPDATE: set a static outbound path
 virtual $static::PROXY_CHAIN_VIP

 SSL::disable clientside
 SSL::disable serverside
 HTTP::disable

 sharedvar ctx

 set ctx(log) 0
 set srcIP [IP::client_addr]
 set dstIP [IP::local_addr]
 set srcPort [TCP::client_port]
 set dstPort [TCP::local_port]
 set ctx(SNI) ""
 set ctx(ptcl) "unknown"
 set ctx(xpinfo) ""

 sharedvar XPHOST
 if { [info exists XPHOST] } {
  if { $XPHOST eq "" } {
   call /Common/sslo_${APP}.app/sslo_${APP}-lib::log 0 "CLIENT_ACCEPTED invalid host (${XPHOST}) for explicit-proxy client ${srcIP}_${srcPort}"
   TCP::respond "HTTP/1.1 500 Server Error\r\nConnection: close\r\n\r\n"
   TCP::close
   return
  }

  if {$ctx(log)} {
   set ctx(xpinfo) "\x20explicit-proxy request ${XPHOST}"
  }

  set ctx(ptcl) "http"
 } else {
  # maintain the next two lists in lockstep (!)
  if {[set x [lsearch -integer -sorted [list 21 22 25 53 80 110 115 143 443 465 587 990 993 995 3128 8080] [TCP::local_port]]] >= 0} {
   set ctx(ptcl) [lindex [list "ftp" "ssh" "smtp" "dns" "http" "pop3" "sftp" "imap" "https" "smtps" "smtp" "ftps" "imaps" "pop3s" "http" "http"] $x]
  }
 }

 if {$ctx(log) > 1} {
  call /Common/sslo_${APP}.app/sslo_${APP}-lib::log 2 "CLIENT_ACCEPTED TCP from ${srcIP}_${srcPort} to ${dstIP}_${dstPort}${ctx(xpinfo)} L7 guess=$ctx(ptcl)"
 }

 ## DYNAMIC EGRESS UPDATE: disable SSF detection
 TCP::collect 1
} ; #CLIENT_ACCEPTED


when CLIENT_DATA priority 250 {
 ## DYNAMIC EGRESS UPDATE: disable corresponding -in-t event
 event disable

 set len [TCP::payload length]
 if { [info exists ctx(ssf)] } {
  #someone beat us to it
  TCP::release
  return
 } elseif {!$len} {
  call /Common/sslo_${APP}.app/sslo_${APP}-lib::log 2 "CLIENT_DATA got empty payload, retrying"
  TCP::collect
  return
 } else {
  set ctx(csf) true
  set said [TCP::payload]
  # release accepted event, if held, to proxy for creating connection to server

  ## DYNAMIC EGRESS UPDATE: disable SSF detection
  #TCP::release 0
 }

 # got at least one octet

 if {($len < 44) &&
     ( ([binary scan $said c type] == 1) &&
       (($type & 0xff) == 22) )} {
  # may be partial TLS Client Hello (unusual)
  # allow up to 7 seconds for the rest to arrive
  # by modifying the connection idle timer. This will be
  # reset after we get the complete hello (or plaintext data)
  if {$ctx(log) > 1} {
   call /Common/sslo_${APP}.app/sslo_${APP}-lib::log 2 "CLIENT_DATA Incomplete Client Hello, set idle timeout to 7 sec"
  }
  set ipIdleTmo [IP::idle_timeout]
  IP::idle_timeout 7
 } ; #(partial Client Hello)

 if {[info exists ctx(httpconn)] && ([ACCESS::perflow get perflow.ssl_bypass_set] == 1)} {
  call /Common/sslo_${APP}.app/sslo_${APP}-lib::log 2 "CLIENT_DATA SSL bypass set inside HTTP CONNECT"
  CONNECTOR::enable
 }

 SSL::enable clientside

 after 0 { TCP::release }
} ; #CLIENT_DATA
