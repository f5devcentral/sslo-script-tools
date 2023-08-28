#!/bin/bash
# SSLO DNS Sinkhole Internal Config Creator
# Author: kevin-at-f5-dot-com
# Version: 20230828-1
# Creates the sinkhole cert/key and internal VIP configuration

## Create the sinkhole cert and key with empty Subject field
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
(echo create cli transaction
echo install sys crypto key sinkhole-cert from-local-file "$(pwd)/sinkhole.key"
echo install sys crypto cert sinkhole-cert from-local-file "$(pwd)/sinkhole.crt"
echo submit cli transaction
) | tmsh > /dev/null 2>&1

## Create sinkhole client SSL profile and virtual server
tmsh create ltm profile client-ssl sinkhole-clientssl cert sinkhole-cert key sinkhole-cert > /dev/null 2>&1
tmsh create ltm virtual sinkhole-internal-vip destination 0.0.0.0:9999 profiles replace-all-with { tcp http sinkhole-clientssl } vlans-enabled > /dev/null 2>&1

rm -f sinkhole.crt sinkhole.key
