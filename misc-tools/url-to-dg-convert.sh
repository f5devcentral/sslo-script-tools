#!/bin/bash

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
