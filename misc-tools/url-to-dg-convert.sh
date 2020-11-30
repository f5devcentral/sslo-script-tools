#!/bin/bash

## This script will convert a custom URL category to a string data group. It is currently configured to convert the built-in SSL Orchestrator Pinners URL category, but can be used for other custom URL categories. Change the name of the custom URL category on the 'tmsh' line, and change the data group name on the 'ltm data-group' line.

## Create this script in a directory on the BIG-IP and 'chmod +x <script>' to make executable.

## get url category entries
tmsh list sys url-db url-category sslo-urlCatPinners urls |grep -E '^\s*http' |sed -E 's/\s*//;s/https?:\/\///;s/\\\*//;s/\/.*//' > tmp_cat

## create data group object
echo "ltm data-group internal sslo-urlCatPinners {" > tmp_dg
echo "   records {" >> tmp_dg

while read p
do
   echo "      ${p} { }" >> tmp_dg
done < tmp_cat

echo "   }" >> tmp_dg
echo "   type string" >> tmp_dg
echo "}" >> tmp_dg

## merge data group object into big-ip config
tmsh load sys config merge file tmp_dg

## delete temp files
rm -f tmp_cat
rm -f tmp_dg
