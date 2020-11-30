#!/bin/bash
# SSL Orchestrator Nuclear Delete Script
# Version: 7.0
# Last Modified: October 2020
# Update author: Kevin Stewart, Sr. SSA F5 Networks
#
# >>> NOTE: THIS VERSION OF THE NUCLEAR DELETE SUPPORTED BY SSL ORCHESTRATOR 5.0 OR HIGHER <<<
#

#-----------------------------------------------------------------------
# User Options - Modify as necessary
#-----------------------------------------------------------------------
user_pass='admin:admin'


#-----------------------------------------------------------------------
# Fetch existing installed RPM
#-----------------------------------------------------------------------
installed_rpm=$(restcurl shared/iapp/installed-packages |grep "packageName" |awk -F"\"" '{print $4}')


#-----------------------------------------------------------------------
# Delete iApp blocks and packages
#-----------------------------------------------------------------------
echo "** Deleting iApp templates and installed package"
blocks=$(restcurl shared/iapp/blocks | grep "      \"id\":" |grep -v "       \"id\":" |awk -F"\"" '{print $4}')
for b in $blocks
do
   restcurl -X DELETE shared/iapp/blocks/${b} > /dev/null 2>&1
done
packages=$(restcurl shared/iapp/installed-packages | grep "      \"id\":" |grep -v "       \"id\":" |awk -F"\"" '{print $4}')
for p in $packages
do
   restcurl -X DELETE shared/iapp/installed-packages/${p} > /dev/null 2>&1
done


#-----------------------------------------------------------------------
# Delete application service templates
#-----------------------------------------------------------------------
echo "** Deleting application services"
appsvcs=$(restcurl -u ${user_pass} mgmt/tm/sys/application/service | jq -r '.items[].fullPath' |sed 's/\/Common\///g' |grep ^sslo)
for a in $appsvcs
do
   tmsh modify sys application service ${a} strict-updates disabled
   tmsh delete sys application service ${a}
done


#-----------------------------------------------------------------------
# Unbind SSLO objects
#-----------------------------------------------------------------------
echo "** Unbinding SSLO objects"
for block in `curl -sk -X GET 'https://localhost/mgmt/shared/iapp/blocks?$select=id,state,name&$filter=state%20eq%20%27*%27%20and%20state%20ne%20%27TEMPLATE%27' -u ${user_pass} | jq -r '.items[] | [.name, .id] |join(":")' |grep -E '^sslo|f5-ssl-orchestrator' | awk -F":" '{print $2}'`; do
   curl -sk -X PATCH "https://localhost/mgmt/shared/iapp/blocks/${block}" -d '{state:"UNBINDING"}' -u ${user_pass} > /dev/null 2>&1
   sleep 15
   curl -sk -X DELETE "https://localhost/mgmt/shared/iapp/blocks/${block}" -u ${user_pass} > /dev/null 2>&1
done


#-----------------------------------------------------------------------
# Delete SSLO objects
#-----------------------------------------------------------------------
echo "** Deleting SSLO objects"
sslo_objects=''
sslo_objects=`tmsh list |grep -v "^\s" |grep sslo |sed -e 's/{//g;s/}//g' |grep -v "apm profile access /Common/ssloDefault_accessProfile" |grep -v "apm log-setting /Common/default-sslo-log-setting" |grep -v "net dns-resolver /Common/ssloGS_global.app/ssloGS-net-resolver" |grep -v "sys application service /Common/ssloGS_global.app/ssloGS_global" |grep -v "sys provision sslo"`
tmsh delete apm profile access /Common/ssloDefault_accessProfile > /dev/null 2>&1
tmsh delete net dns-resolver /Common/ssloGS_global.app/ssloGS-net-resolver > /dev/null 2>&1
tmsh delete sys application service /Common/ssloGS_global.app/ssloGS_global > /dev/null 2>&1
tmsh delete apm policy access-policy /Common/ssloDefault_accessPolicy > /dev/null 2>&1

while read -r line
do
    if [ ! -z "$sslo_objects" ]
    then
       eval "tmsh delete $line" > /dev/null 2>&1
    fi
done <<< "$sslo_objects"


#-----------------------------------------------------------------------
# Delete application service templates (again)
#-----------------------------------------------------------------------
appsvcs=$(restcurl -u ${user_pass} mgmt/tm/sys/application/service | jq -r '.items[].fullPath' |sed 's/\/Common\///g' |grep ^sslo)
for a in $appsvcs
do
   tmsh modify sys application service ${a} strict-updates disabled
   tmsh delete sys application service ${a}
done


#-----------------------------------------------------------------------
# Unbind SSLO objects (again)
#-----------------------------------------------------------------------
echo "** Unbinding SSLO objects"
for block in `curl -sk -X GET 'https://localhost/mgmt/shared/iapp/blocks?$select=id,state,name&$filter=state%20eq%20%27*%27%20and%20state%20ne%20%27TEMPLATE%27' -u ${user_pass} | jq -r '.items[] | [.name, .id] |join(":")' |grep -E '^sslo|f5-ssl-orchestrator' | awk -F":" '{print $2}'`; do
   curl -sk -X PATCH "https://localhost/mgmt/shared/iapp/blocks/${block}" -d '{state:"UNBINDING"}' -u ${user_pass} > /dev/null 2>&1
   sleep 15
   curl -sk -X DELETE "https://localhost/mgmt/shared/iapp/blocks/${block}" -u ${user_pass} > /dev/null 2>&1
done


#-----------------------------------------------------------------------
# Clear REST storage
#-----------------------------------------------------------------------
echo "** Clearing REST storage"
clear-rest-storage -l > /dev/null 2>&1


#-----------------------------------------------------------------------
# Pause for 5 seconds
#-----------------------------------------------------------------------
sleep 5


#-----------------------------------------------------------------------
# Re-install the previously-installed RPM
#-----------------------------------------------------------------------
DATA="{\"operation\":\"INSTALL\",\"packageFilePath\":\"/var/config/rest/downloads/${installed_rpm}.rpm\"}"
restcurl -u ${user_pass} -X POST "shared/iapp/package-management-tasks" -d ${DATA} > /dev/null 2>&1


echo "** Complete - Run this script again if any errors are output."
