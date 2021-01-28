## Rule: SSL Orchestrator DNS-over-HTTPS detection, logging and blackholing
## Author: Kevin Stewart
## Version: 1, 1/2021
## Function: Creates a mechanism to detect, log, and potentially blackhole DNS-over-HTTPS requests through an SSL Orchestrator outbound topology.
## Instructions: 
##  - Under Local Traffic -> iRules in the BIG-IP UI, import the required iRule.
##  - In the SSL Orchestrator UI, under the Interception Rules tab, click on the interception rule to edit (typically ending with "-in-t"), and at the bottom of this configuration page, add the iRule and then (re)deploy.
##  - If using the DoH detection and logging iRule, additional configuration is required (see README).
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
    set static::BLACKHOLE_URLS {

    }
    
    ## User-defined: if enabled, generate blachole DNS responses for these record types
    ## Disabled (value: 0) or enabled (value: 1)
    set static::BLACKHOLE_RTYPE_A       1
    set static::BLACKHOLE_RTYPE_AAAA    1
    set static::BLACKHOLE_RTYPE_TXT     1
    
    ## Set DNS record types: (ex. A=1, AAAA=28) ref: https://www.iana.org/assignments/dns-parameters/dns-parameters.xhtml
    array set static::dns_codes { 1 A 2 NS 5 CNAME 6 SOA 12 PTR 16 TXT 28 AAAA 33 SRV 257 CAA }
}
proc DOH_URL_BLOCK { id name ver hsl } {
    ## This procedure consumes the query type id (A,AAAA), query name, DoH version (WF or JSON) and HSL object
    ## and generates a blackhole DNS response is the name matches a defined URL category. Works for A, AAAA, and TXT records.
    set type [lindex [split ${name} ":"] 0]
    set name [lindex [split ${name} ":"] 1]
    
    if { ${static::URLDB_LICENSED}} {
        set match 0 ; if { [llength ${static::BLACKHOLE_URLS}] > 0 } { set res [CATEGORY::lookup "https://${name}/" request_default_and_custom] ; foreach url ${res} { if { [lsearch -exact ${static::BLACKHOLE_URLS} ${url}] >= 0 } { set match 1 } } }
    } else {
        set match 0 ; if { [llength ${static::BLACKHOLE_URLS}] > 0 } { set res [CATEGORY::lookup "https://${name}/" custom] ; foreach url ${res} { if { [lsearch -exact ${static::BLACKHOLE_URLS} ${url}] >= 0 } { set match 1 } } }
    }

    if { ${match} } {
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
                append retstring {0000010001c00c00010001000118c30004c7c7c7c7}
                call DOH_LOG "Sending DoH Blackhole for Request" "${type}:${name}" ${hsl}
                HTTP::respond 200 content [binary format H* ${retstring}] "Content-Type" "application/dns-message" "Access-Control-Allow-Origin" "*"
            } elseif { ${ver} eq "JSON" } {
                set template "\{\"Status\": 0,\"TC\": false,\"RD\": true,\"RA\": true,\"AD\": true,\"CD\": false,\"Question\": \[\{\"name\": \"BLACKHOLE_TEMPLATE\",\"type\": 1 \}\],\"Answer\": \[\{\"name\": \"BLACKHOLE_TEMPLATE\",\"type\":1,\"TTL\": 84078,\"data\": \"199.199.199.199\" \}\]\}"
                set template [string map [list "BLACKHOLE_TEMPLATE" ${name}] ${template}]
                call DOH_LOG "Sending DoH Blackhole for Request" "${type}:${name}" ${hsl}
                HTTP::respond 200 content ${template} "Content-Type" "application/dns-json" "Access-Control-Allow-Origin" "*"
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
when CLIENT_ACCEPTED {
    ## This event establishes HSL connection (as required) and sends reject if destination address is the blackhole IP.
    if { ${static::HSL} ne "none" } { set hsl [HSL::open -proto UDP -pool ${static::HSL}] } else { set hsl "none" } 
    if { [IP::local_addr] eq "199.199.199.199" } { reject }
    if { [IP::local_addr] eq "0:0:0:0:0:ffff:c7c7:c7c7" } { reject }
}
when HTTP_REQUEST priority 750 {
    ## Thsi event parses the request looking for DoH type messages.
    if { ( [HTTP::method] equals "GET" and [HTTP::header exists "accept"] and [HTTP::header "accept"] equals "application/dns-json" ) } {
        ## JSON DoH request
        set type [URI::query [HTTP::uri] type] ; if { ${type} eq "" } { set type "A" }
        set name [URI::query [HTTP::uri] name] ; if { ${name} ne "" } { call DOH_LOG "DoH (JSON GET) Request" "${type}:${name}" ${hsl} }
        call DOH_URL_BLOCK "null" "${type}:${name}" "JSON" ${hsl}
    } elseif { ( [HTTP::method] equals "GET" and [HTTP::header exists "accept"] and [HTTP::header "accept"] equals "application/dns-message" ) } {
        ## DNS WireFormat DoH GET request
        if { [set name [URI::query [HTTP::uri] dns]] >= 0 } {
            binary scan [b64decode ${name}] H* tmp
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
