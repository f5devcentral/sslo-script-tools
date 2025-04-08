#!/bin/bash

## Set category names
AI_CHAT_CATEGORY="SSLO_GENERATIVE_AI_CHAT"

## Set category URLs
AI_CHAT_URL="https://raw.githubusercontent.com/f5devcentral/sslo-script-tools/main/sslo-generative-ai-categories/ai-tools-urls"

## Fetch remote URL category
curl -sO ${AI_CHAT_URL}

## Get current datetime
TIMESTAMP=$(date +"%Y%m%d")

## Loop through URL list to build category data
for url in $(cat ai-category-chat)
do
    ## If url contains "*", set as a glob-match URL, otherwise exact-match
    if [[ $url =~ "*" ]]
    then
        url=$(echo $url | sed -E 's/\*/\\*/')
        str_urls="${str_urls} urls add { \"https://${url}/\" { type glob-match }} urls add { \"http://${url}/\" { type glob-match }}"
    else
        str_urls="${str_urls} urls add { \"https://${url}/\" { type exact-match }} urls add { \"http://${url}/\" { type exact-match }}"
    fi
done

## Test for existing custom URL category
exists=true && [[ "$(tmsh list /sys url-db url-category ${AI_CHAT_CATEGORY} 2>&1)" =~ "was not found" ]] && config=false
if ($config)
then
    ## Category exists - overwrite
    tmsh -a modify /sys url-db url-category ${AI_CHAT_CATEGORY} display-name "${AI_CHAT_CATEGORY}" urls replace-all-with { https://${TIMESTAMP}/ { type exact-match } } default-action allow 2>&1
else
    ## Category doesn't exist - create
    tmsh -a create /sys url-db url-category ${AI_CHAT_CATEGORY} display-name "${AI_CHAT_CATEGORY}" urls replace-all-with { https://${TIMESTAMP}/ { type exact-match } } default-action allow 2>&1    
fi

## Populate category with URLs
tmsh -a modify /sys url-db url-category ${AI_CHAT_CATEGORY} ${str_urls} 2>&1

## Clean up temp files
rm -f ai-category-chat
