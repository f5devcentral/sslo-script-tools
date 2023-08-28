## Rule: SSL Orchestrator DNS-over-HTTPS detection, logging and blackholing, and sinkhole support
## Author: Kevin Stewart
## Version: 20230828-5
## Function: Creates a mechanism to detect, log, and potentially blackhole DNS-over-HTTPS requests through an SSL Orchestrator outbound topology.
## Instructions: 
##  - Under Local Traffic -> iRules in the BIG-IP UI, import the required iRule.
##  - In the SSL Orchestrator UI, under the Interception Rules tab, click on the interception rule to edit (typically ending with "-in-t"), and at the bottom of this configuration page, add the iRule and then (re)deploy.
##  - If using the DoH detection and logging iRule, additional configuration is required (see README).
## Ref: https://github.com/f5devcentral/sslo-script-tools/tree/main/sslo-dns-over-https-detection

when RULE_INIT {
    ## User-defined: send log traffic to local syslog facility (not recommended under load)
    ## Disabled (value: 0) or enabled (value: 1)
    set static::LOCAL_LOG 0

    ## User-defined: send log traffic to external Syslog service via high-speed logging (HSL)
    ## Disable HSL (value: "none") or enable (value: syslog pool name)
    #set static::HSL "syslog-pool"
    set static::HSL "none"

    ## User-defined: is URLDB licensed and provisioned (otherwise local custom URL categories are still available)
    ## Disabled (value: 0) or enabled (value: 1)
    set static::URLDB_LICENSED 0

    ## User-defined: generate blackhole DNS responses for these URL categories.
    ## Disabled (value: empty) or enabled (value: names of URL categories to block)
    ## If URLDB is not licensed and provisioned, this list can still contain local custom URL categories
    ## 
    ## For custom URL categories, enter the URLs to block in this format: https://[domain]/. Example:
    ##   https://www.example.com/
    ## 
    ## Add the URL categories to the following block. Example:
    ##   set static::BLACKHOLE_URLCAT {
    ##      /Common/block-doh-urls
    ##   }
    set static::BLACKHOLE_URLCAT {
        
    }
    
    ## User-defined: sinkhole IP address
    set static::SINKHOLE_IP ""

    ## User-defined: if enabled, generate blachole DNS responses for these record types
    ## Disabled (value: 0) or enabled (value: 1)
    set static::BLACKHOLE_RTYPE_A       1
    set static::BLACKHOLE_RTYPE_AAAA    1
    set static::BLACKHOLE_RTYPE_TXT     1

    ## Set DNS record types: (ex. A=1, AAAA=28) ref: https://www.iana.org/assignments/dns-parameters/dns-parameters.xhtml
    #array set static::dns_codes { 1 A 2 NS 5 CNAME 6 SOA 12 PTR 16 TXT 28 AAAA 33 SRV 257 CAA }
    array set static::dns_codes { 1 A 2 NS 5 CNAME 6 SOA 12 PTR 13 HINFO 15 MX 16 TXT 17 RP 18 AFSDB 28 AAAA 29 LOC 33 SRV 35 NAPTR 37 CERT 39 DNAME 43 DS 46 RRSIG 47 NSEC 48 DNSKEY 49 DHCID 50 NSEC3 51 NSEC3PARAM 52 TLSA 65 HTTPS 99 SPF 257 CAA }
}
proc ip_to_hex { ip4 } {
    set iplist [split ${ip4} "."]
    set ipint [expr { \
        [expr { [lindex ${iplist} 3] }] + \
        [expr { [lindex ${iplist} 2] * 256 }] + \
        [expr { [lindex ${iplist} 1] * 65536 }] + \
        [expr { [lindex ${iplist} 0] * 16777216 }] \
    }]
    return [format %x ${ipint}]
}
proc DOH_URL_BLOCK { id name ver hsl } {
    ## This procedure consumes the query type id (A,AAAA), query name, DoH version (WF or JSON) and HSL object
    ## and generates a blackhole DNS response is the name matches a defined URL category. Works for A, AAAA, and TXT records.
    set type [lindex [split ${name} ":"] 0]
    set name [lindex [split ${name} ":"] 1]

    if { ${static::URLDB_LICENSED}} {
        set match 0 ; if { [llength ${static::BLACKHOLE_URLCAT}] > 0 } { set res [CATEGORY::lookup "https://${name}/" request_default_and_custom] ; foreach url ${res} { if { [lsearch -exact ${static::BLACKHOLE_URLCAT} ${url}] >= 0 } { set match 1 } } }
    } else {
        set match 0 ; if { [llength ${static::BLACKHOLE_URLCAT}] > 0 } { set res [CATEGORY::lookup "https://${name}/" custom] ; foreach url ${res} { if { [lsearch -exact ${static::BLACKHOLE_URLCAT} ${url}] >= 0 } { set match 1 } } }
    }

    if { ${match} } {
        ## Get sinkhole IP, or use default
        if { $static::SINKHOLE_IP ne "" } {
            set ipinjected $static::SINKHOLE_IP
            set iphexinjected [call ip_to_hex $static::SINKHOLE_IP]
        } else {
            set ipinjected "199.199.199.199"
            set iphexinjected [call ip_to_hex "199.199.199.199"]
        }
        
        if { ( ${type} eq "A" ) and ( ${static::BLACKHOLE_RTYPE_A} ) } {
            if { ${ver} eq "WF" } {
                ## build DNS A record blackhole response
                set retstring "${id}81800001000100000000"
                foreach x [split ${name} "."] {
                    append retstring [format %02x [string length ${x}]]
                    foreach y [split ${x} ""] {
                        append retstring [format %02x [scan ${y} %c]]
                    }
                }
                ## c7c7c7c7c = 199.199.199.199
                #append retstring {0000010001c00c00010001000118c30004c7c7c7c7}
                append retstring "0000010001c00c00010001000118c300040${iphexinjected}"
                call DOH_LOG "Sending DoH Blackhole for Request" "${type}:${name}" ${hsl}
                HTTP::respond 200 content [binary format H* ${retstring}] "Content-Type" "application/dns-message" "Access-Control-Allow-Origin" "*"
            } elseif { ${ver} eq "JSON" } {
                #set template "\{\"Status\": 0,\"TC\": false,\"RD\": true,\"RA\": true,\"AD\": true,\"CD\": false,\"Question\": \[\{\"name\": \"BLACKHOLE_TEMPLATE\",\"type\": 1 \}\],\"Answer\": \[\{\"name\": \"BLACKHOLE_TEMPLATE\",\"type\":1,\"TTL\": 84078,\"data\": \"199.199.199.199\" \}\]\}"
                set template "\{\"Status\": 0,\"TC\": false,\"RD\": true,\"RA\": true,\"AD\": true,\"CD\": false,\"Question\": \[\{\"name\": \"BLACKHOLE_TEMPLATE\",\"type\": 1 \}\],\"Answer\": \[\{\"name\": \"BLACKHOLE_TEMPLATE\",\"type\":1,\"TTL\": 84078,\"data\": \"${ipinjected}\" \}\]\}"
                set template [string map [list "BLACKHOLE_TEMPLATE" ${name}] ${template}]
                call DOH_LOG "Sending DoH Blackhole for Request" "${type}:${name}" ${hsl}
                HTTP::respond 200 content ${template} "Content-Type" "application/dns-json" "Access-Control-Allow-Origin" "*"
            } elseif { ${ver} eq "DoT" } {
                ## build DNS A record blackhole response
                set retstring "${id}81800001000100000000"
                foreach x [split ${name} "."] {
                    append retstring [format %02x [string length ${x}]]
                    foreach y [split ${x} ""] {
                        append retstring [format %02x [scan ${y} %c]]
                    }
                }
                ## c7c7c7c7c = 199.199.199.199
                #append retstring {0000010001c00c00010001000118c30004c7c7c7c7}
                append retstring "0000010001c00c00010001000118c300040${iphexinjected}"
                set lenhex [format %04x [string length ${retstring}]]
                set retstring "${lenhex}${retstring}"
                call DOH_LOG "Sending DoT Blackhole for Request" "${type}:${name}" ${hsl}
                SSL::respond [binary format H* ${retstring}]
            }
        } elseif { ( ${type} eq "AAAA" ) and ( ${static::BLACKHOLE_RTYPE_AAAA} ) } {
            if { ${ver} eq "WF" } {
                ## build DNS A record blackhole response
                set retstring "${id}81800001000100000000"
                foreach x [split ${name} "."] {
                    append retstring [format %02x [string length ${x}]]
                    foreach y [split ${x} ""] {
                        append retstring [format %02x [scan ${y} %c]]
                    }
                }
                ## 0:0:0:0:0:ffff:c7c7:c7c7
                append retstring {00001c0001c00c001c00010001488100100000000000000000000ffffc7c7c7c7}
                call DOH_LOG "Sending DoH Blackhole for Request" "${type}:${name}" ${hsl}
                HTTP::respond 200 content [binary format H* ${retstring}] "Content-Type" "application/dns-message" "Access-Control-Allow-Origin" "*"
            } elseif { ${ver} eq "JSON" } {
                set template "\{\"Status\": 0,\"TC\": false,\"RD\": true,\"RA\": true,\"AD\": true,\"CD\": false,\"Question\": \[\{\"name\": \"BLACKHOLE_TEMPLATE\",\"type\": 28 \}\],\"Answer\": \[\{\"name\": \"BLACKHOLE_TEMPLATE\",\"type\":28,\"TTL\": 84078,\"data\": \"0:0:0:0:0:ffff:c7c7:c7c7\" \}\]\}"
                set template [string map [list "BLACKHOLE_TEMPLATE" ${name}] ${template}]
                call DOH_LOG "Sending DoH Blackhole for Request" "${type}:${name}" ${hsl}
                HTTP::respond 200 content ${template} "Content-Type" "application/dns-json" "Access-Control-Allow-Origin" "*"
            } elseif { ${ver} eq "DoT" } {
                ## build DNS A record blackhole response
                set retstring "${id}81800001000100000000"
                foreach x [split ${name} "."] {
                    append retstring [format %02x [string length ${x}]]
                    foreach y [split ${x} ""] {
                        append retstring [format %02x [scan ${y} %c]]
                    }
                }
                ## 0:0:0:0:0:ffff:c7c7:c7c7
                append retstring {00001c0001c00c001c00010001488100100000000000000000000ffffc7c7c7c7}
                set lenhex [format %04x [string length ${retstring}]]
                set retstring "${lenhex}${retstring}"
                call DOH_LOG "Sending DoT Blackhole for Request" "${type}:${name}" ${hsl}
                SSL::respond [binary format H* ${retstring}]
            }
        } elseif { ( ${type} eq "TXT" ) and ( ${static::BLACKHOLE_RTYPE_TXT} ) } {
            if { ${ver} eq "WF" } {
                ## build DNS A record blackhole response
                set retstring "${id}81800001000100000000"
                foreach x [split ${name} "."] {
                    append retstring [format %02x [string length ${x}]]
                    foreach y [split ${x} ""] {
                        append retstring [format %02x [scan ${y} %c]]
                    }
                }
                ## generic "v=spf1 -all"
                append retstring {0000100001c00c0010000100002a30000c0b763d73706631202d616c6c}
                call DOH_LOG "Sending DoH Blackhole for Request" "${type}:${name}" ${hsl}
                HTTP::respond 200 content [binary format H* ${retstring}] "Content-Type" "application/dns-message" "Access-Control-Allow-Origin" "*"
            } elseif { ${ver} eq "JSON" } {
                set template "\{\"Status\": 0,\"TC\": false,\"RD\": true,\"RA\": true,\"AD\": true,\"CD\": false,\"Question\": \[\{\"name\": \"BLACKHOLE_TEMPLATE\",\"type\": 16 \}\],\"Answer\": \[\{\"name\": \"BLACKHOLE_TEMPLATE\",\"type\":16,\"TTL\": 84078,\"data\": \"v=spf1 -all\" \}\]\}"
                set template [string map [list "BLACKHOLE_TEMPLATE" ${name}] ${template}]
                call DOH_LOG "Sending DoH Blackhole for Request" "${type}:${name}" ${hsl}
                HTTP::respond 200 content ${template} "Content-Type" "application/dns-json" "Access-Control-Allow-Origin" "*"
            } elseif { ${ver} eq "DoT" } {
                ## build DNS A record blackhole response
                set retstring "${id}81800001000100000000"
                foreach x [split ${name} "."] {
                    append retstring [format %02x [string length ${x}]]
                    foreach y [split ${x} ""] {
                        append retstring [format %02x [scan ${y} %c]]
                    }
                }
                ## generic "v=spf1 -all"
                append retstring {0000100001c00c0010000100002a30000c0b763d73706631202d616c6c}
                set lenhex [format %04x [string length ${retstring}]]
                set retstring "${lenhex}${retstring}"
                call DOH_LOG "Sending DoT Blackhole for Request" "${type}:${name}" ${hsl}
                SSL::respond [binary format H* ${retstring}]
            }
        }
    }
}
proc DOH_LOG { msg name hsl } {
    ## This procedure consumes the message string, DoH question name, and HSL object to generates log messages.
    if { ${static::LOCAL_LOG} } { log -noname local0. "[IP::client_addr]:[TCP::client_port]-[IP::local_addr]:[TCP::local_port] :: ${msg}: ${name}" }
    if { ${static::HSL} ne "none" } { HSL::send ${hsl} "<190> [IP::client_addr]:[TCP::client_port]-[IP::local_addr]:[TCP::local_port] :: ${msg}: ${name}" }
}
proc DECODE_DNS_REQ { data } {
    ## This procedure consumes the HEX-encoded DoH question and decodes to return the question name and type (A,AAAA,TXT, etc.).
    if { [catch { 
        set name "" ; set pos 0 ; set num 0 ; set count 0 ; set typectr 0 ; set type ""
        ## process question
        foreach {i j} [split ${data} ""] {
            scan ${i}${j} %x num
            if { ${typectr} > 0 } {
                append type "${i}${j}"
                if { ${typectr} == 2 } { break }
                incr typectr
            } elseif { ${num} == 0 } {
                ## we're done
                set typectr 1
                #break
            } elseif { ${num} < 31 } {
                set pos 1
                set count ${num}
                append name "."
            } elseif { [expr { ${pos} <= ${count} }] } {
                set char [binary format H* ${i}${j}]
                append name $char
                incr pos
            }
        }
        set name [string range ${name} 1 end]
        ## process qtype
        if { [catch {
            scan ${type} %xx type
            set typestr $static::dns_codes(${type})
        }] } {
            set typestr "UNK"
        } 
    }] } {
        return "error"
    } else {
        return "${typestr}:${name}"
    }
}
proc SAFE_BASE64_DECODE { payload } {
    if { [catch {b64decode "${payload}[expr {[string length ${payload}] % 4 == 0 ? "":[string repeat "=" [expr {4 - [string length ${payload}] % 4}]]}]"} decoded_value] == 0 and ${decoded_value} ne "" } {
        return ${decoded_value}
    } else {
        return 0
    }
}
when CLIENT_ACCEPTED {
    ## This event establishes HSL connection (as required) and sends reject if destination address is the blackhole IP.
    if { ${static::HSL} ne "none" } { set hsl [HSL::open -proto UDP -pool ${static::HSL}] } else { set hsl "none" } 
    if { [IP::local_addr] eq "199.199.199.199" } { reject }
    if { [IP::local_addr] eq "0:0:0:0:0:ffff:c7c7:c7c7" } { reject }
}
when CLIENTSSL_HANDSHAKE priority 50 {
    ## This event triggers on decrypted DoT requests.
    if { [TCP::local_port] eq "853" } {
        SSL::collect
    }
}
when CLIENTSSL_DATA priority 50 {
    ## This event is triggered parse the decrypted DoT request.
    if { [TCP::local_port] eq "853" } {
        binary scan [SSL::payload] H* tmp
        set id [string range ${tmp} 4 7]
        set tmp [string range ${tmp} 28 end]
        if { [set name [call DECODE_DNS_REQ ${tmp}]] ne "error" } {
            call DOH_LOG "DoT Request" ${name} ${hsl}
            call DOH_URL_BLOCK ${id} ${name} "DoT" ${hsl}
        }
        SSL::release
    }
}
when HTTP_REQUEST priority 750 {
    ## This event parses the request looking for DoH type messages.
    if { ( [HTTP::method] equals "GET" and [HTTP::header exists "accept"] and [HTTP::header "accept"] equals "application/dns-json" ) } {
        ## JSON DoH request
        set type [URI::query [HTTP::uri] type] ; if { ${type} eq "" } { set type "A" }
        set name [URI::query [HTTP::uri] name] ; if { ${name} ne "" } { call DOH_LOG "DoH (JSON GET) Request" "${type}:${name}" ${hsl} }
        call DOH_URL_BLOCK "null" "${type}:${name}" "JSON" ${hsl}
    } elseif { ( ( [HTTP::method] equals "GET" and [HTTP::header exists "content-type"] and [HTTP::header "content-type"] equals "application/dns-message" ) \
                or ( [HTTP::method] equals "GET" and [HTTP::header exists "accept"] and [HTTP::header "accept"] equals "application/dns-message" ) ) } {
        ## DNS WireFormat DoH GET request
        if { [set name [URI::query [HTTP::uri] dns]] >= 0 } {
            ## Use this construct to handle potentially missing padding characters
            binary scan [call SAFE_BASE64_DECODE ${name}] H* tmp
            set id [string range ${tmp} 0 3]
            set tmp [string range ${tmp} 24 end]
            if { [set name [call DECODE_DNS_REQ ${tmp}]] ne "error" } {
                call DOH_LOG "DoH (WireFormat GET) Request" ${name} ${hsl}
                call DOH_URL_BLOCK ${id} ${name} "WF" ${hsl}
            }
        }
    } elseif { ( [HTTP::method] equals "POST" and [HTTP::header exists "content-type"] and [HTTP::header "content-type"] equals "application/dns-message" ) } {
        ## DNS WireFormat DoH POST request
        HTTP::collect 100
    }
}
when HTTP_REQUEST_DATA priority 250 {
    binary scan [HTTP::payload] H* tmp
    set id [string range ${tmp} 0 3]
    set tmp [string range ${tmp} 24 end]
    if { [set name [call DECODE_DNS_REQ ${tmp}]] ne "error" } {
        call DOH_LOG "DoH (WireFormat POST) Request" ${name} ${hsl}
        call DOH_URL_BLOCK ${id} ${name} "WF" ${hsl}
    }
}
