#!/bin/bash
# SSL Orchestrator DNS Sinkhole Internal Config Creator
# Author: kevin-at-f5-dot-com
# Version: 20250806-1
# Creates the sinkhole cert/key and internal VIP configuration

## Create the sinkhole cert and key with empty Subject field
echo "..Creating the sinkhole certificate and key"
openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
-keyout "sinkhole.key" \
-out "sinkhole.crt" \
-subj "/" \
-config <(printf "[req]\n
distinguished_name=dn\n
x509_extensions=v3_req\n
[dn]\n\n
[v3_req]\n
keyUsage=critical,digitalSignature,keyEncipherment\n
extendedKeyUsage=serverAuth,clientAuth") > /dev/null 2>&1

## Update the BIG-IP sinkhole cert/key objects
echo "..Creating the BIG-IP sinkhole certificate and key objects"
(echo create cli transaction
echo install sys crypto key sinkhole-cert from-local-file "$(pwd)/sinkhole.key"
echo install sys crypto cert sinkhole-cert from-local-file "$(pwd)/sinkhole.crt"
echo submit cli transaction
) | tmsh > /dev/null 2>&1

## Create sinkhole client SSL profile and virtual server
echo "..Creating internal sinkhole client SSL profile and virtual server"
tmsh create ltm profile client-ssl sinkhole-clientssl cert sinkhole-cert key sinkhole-cert > /dev/null 2>&1
tmsh create ltm virtual sinkhole-internal-vip destination 0.0.0.0:9999 profiles replace-all-with { tcp http sinkhole-clientssl } vlans-enabled > /dev/null 2>&1

## Install sinkhole-target-rule iRule
echo "..Creating the sinkhole-target-rule iRule"
rule='when CLIENT_ACCEPTED {\n    virtual \"sinkhole-internal-vip\"\n}\nwhen CLIENTSSL_CLIENTHELLO priority 800 {\n    if {[SSL::extensions exists -type 0]} {\n        binary scan [SSL::extensions -type 0] @9a* SNI\n    }\n\n    if { [info exists SNI] } {\n        SSL::forward_proxy extension 2.5.29.17 \"critical,DNS:${SNI}\"\n    }\n}\nwhen HTTP_REQUEST {\n    HTTP::respond 403 content \"<html><head></head><body><h1>Site Blocked!</h1></body></html>\"\n}\n'
data="{\"name\":\"sinkhole-target-rule\",\"apiAnonymous\":\"${rule}\"}"
curl -sk \
-u ${BIGUSER} \
-H "Content-Type: application/json" \
-d "${data}" \
https://localhost/mgmt/tm/ltm/rule -o /dev/null

echo "..Removing temporary files"
rm -f sinkhole.crt sinkhole.key
