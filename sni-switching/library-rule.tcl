proc getSNI { payload } {
    set detect_handshake 1
    set tls_action 0

    binary scan ${payload} H* orig
    if { [binary scan [TCP::payload] cSS tls_xacttype tls_version tls_recordlen] < 3 } {
        reject
        return
    }
    log local0. "payload length [TCP::payload length]"
    log local0. "CLIENT HELLO:- TLS Version: ${tls_version}"
    log local0. "CLIENT HELLO:- TLS Length: ${tls_recordlen}"

    ## 768 SSLv3.0
    ## 769 TLSv1.0
    ## 770 TLSv1.1
    ## 771 TLSv1.2
    switch $tls_version {
        "769" -
        "770" -
        "771" {
            if { ($tls_xacttype == 22) } {
                binary scan ${payload} @5c tls_action
                if { not (($tls_action == 1) && ([string length ${payload}] > $tls_recordlen)) } {
                    set detect_handshake 0
                }
            }
        }
        "768" {
            set detect_handshake 0
        }
        default {
            set detect_handshake 0
        }
    }

    if { ($detect_handshake) } {
        ## skip past the session id
        set record_offset 43
        binary scan ${payload} @${record_offset}c tls_sessidlen
        set record_offset [expr {$record_offset + 1 + $tls_sessidlen}]

        ## skip past the cipher list
        binary scan ${payload} @${record_offset}S tls_ciphlen
        set record_offset [expr {$record_offset + 2 + $tls_ciphlen}]

        ## skip past the compression list
        binary scan ${payload} @${record_offset}c tls_complen
        set record_offset [expr {$record_offset + 1 + $tls_complen}]

        ## check for the existence of ssl extensions
        if { ([string length ${payload}] > $record_offset) } {
            ## skip to the start of the first extension
            binary scan ${payload} @${record_offset}S tls_extenlen
            set record_offset [expr {$record_offset + 2}]
            ## read all the extensions into a variable
            binary scan ${payload} @${record_offset}a* tls_extensions

            ## for each extension
            for { set ext_offset 0 } { $ext_offset < $tls_extenlen } { incr ext_offset 4 } {
                binary scan $tls_extensions @${ext_offset}SS etype elen
                if { ($etype == 0) } {
                    ## if it's a servername extension read the servername
                    set grabstart [expr {$ext_offset + 9}]
                    set grabend [expr {$elen - 5}]
                    binary scan $tls_extensions @${grabstart}A${grabend} tls_servername_orig
                    set tls_servername [string tolower ${tls_servername_orig}]
                    set ext_offset [expr {$ext_offset + $elen}]
                    break
                } else {
                    ## skip over other extensions
                    set ext_offset [expr {$ext_offset + $elen}]
                }
            }
        }
    }

    if { (($tls_action == 1) && ([string length ${payload}] < $tls_recordlen)) } {
        ## This payload does not have entire TLS packet. Do not perform TCP:release yet.    
        return "null"
    }
    elseif { ![info exists tls_servername] } {
        ## This isn't TLS so we can't decrypt it anyway
        TCP::release
        return "null"
    } else {
        TCP::release
        return ${tls_servername}
    }
}
