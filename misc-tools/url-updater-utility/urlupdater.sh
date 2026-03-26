#!/usr/bin/env bash
## F5 Custom URL Category Update Script
## Description: provides options to add URLs, delete URLs, and list the URLs in an existing custom URL category
## Version: 3.1 (26 Mar 2026)
## Author: Kevin Stewart
## Requires: bash, curl, jq
##
## Syntax:
##  --help | -h     = show this help
##  --list | -l     = list entries in the specified URL category
##  --dump | -x     = dump the specified category to a file --> used with --file [file]
##  --add  | -a     = add an entry to the specified URL category. Used with --url (single url) or --file (url file)
##  --del  | -d     = delete an entry from the specified URL category. Used with --url (single url) or --file (url file)
##  --repl | -r     = replace the contents of the specified URL category. Used with --file (url file)
##  --cat  | -c     = a category name
##  --file | -f     = a url file used with --add, --del, and --repl
##  --url  | -u     = a single url used with --add and --del
##  --bigip| -b     = the IP address or hostname of the BIG-IP
##  --user | -i     = username for the BIG-IP (will prompt for password)
##  
## Examples:
##  Show help:            $0 --help
##  List URLs:            $0 --bigip 172.16.1.84 --user admin --cat test-category --list
##  Add single entry:     $0 --bigip 172.16.1.84 --user admin --cat test-category --add --url https://www.foo.com/
##  Add file entries:     $0 --bigip 172.16.1.84 --user admin --cat test-category --add --file testfile.txt
##  Delete single entry:  $0 --bigip 172.16.1.84 --user admin --cat test-category --del --url https://www.foo.com/
##  Delete file entries:  $0 --bigip 172.16.1.84 --user admin --cat test-category --del --file testfile.txt
##  Replace all entries:  $0 --bigip 172.16.1.84 --user admin --cat test-category --repl --file testfile.txt
##
## URL format: supplied URLs must be in the following format:
##  https://URL/
##  
##  Example: https://www.foo.com/
##
CATEGORY=
COMMAND=
URL=
FILE=
BIGIP=
USERNAME=
PASSWORD=
DRYRUN=

# colors
CYAN='\033[36m'
YELLOW='\033[33m'
NC='\033[0m'

set -euo pipefail

## valid external requirements (jq and curl)
if ! command -v curl &> /dev/null; then
    echo -e "\nERROR: curl not found. Please install curl and try again."
    exit 1
fi
if ! command -v jq &> /dev/null; then
    echo -e "\nERROR: jq not found. Please install jq and try again."
    exit 1
fi

# help print
help() {
   echo ""
   echo "Usage: $0 [options]"
   echo " --help | -h               = show this help"
   echo " --list | -l               = list entries in the specified URL category"
   echo " --dump | -x               = dump the specified category to a file --> used with --file [file]"
   echo " --add  | -a               = add a single entry to the specified URL category --> used with --url [url] or --file [file]"
   echo " --del  | -d               = delete a single entry from the specified URL category --> used with --url [url] or --file [file]"
   echo " --repl | -r               = replace the contents of the specified URL category (overwrite) --> used --file [file]"
   echo " --url  | -u [url]         = specifies a single url"
   echo " --file | -f [file]        = specified a url file"
   echo " --bigip| -b [ip|host]     = the IP address or hostname of the BIG-IP"
   echo " --user | -i [user]        = username for the BIG-IP (script will prompt for password)"
   echo ""
   echo "Examples:"
   echo "  Show help:               $0 --help"
   echo "  List URLs:               $0 --bigip 172.16.1.84 --user admin --cat test-category --list"
   echo "  Add single entry:        $0 --bigip 172.16.1.84 --user admin --cat test-category --add-url https://www.foo.com/"
   echo "  Add file entries:        $0 --bigip 172.16.1.84 --user admin --cat test-category --add-file testfile.txt"
   echo "  Delete single entry:     $0 --bigip 172.16.1.84 --user admin --cat test-category --del-url https://www.foo.com/"
   echo "  Delete file entries:     $0 --bigip 172.16.1.84 --user admin --cat test-category --del-file testfile.txt"
   echo "  Replace all entries:     $0 --bigip 172.16.1.84 --user admin --cat test-category --repl-file testfile.txt"
   echo "  Dump to a file:          $0 --bigip 172.16.1.84 --user admin --cat test-category --dump --file catfile.txt"
   echo ""
   exit
}

errorhandler() {
    local msg="${1}"
    echo -e "\n${CYAN}ERROR:${NC} ${YELLOW}${msg}${NC}\n"
    exit 1
}

# function to concat string array with comma separator
joinByString() {
    local separator=","
    local data="$1"
    # shift
    printf "%s" "$first" "${@/#/$separator}"
    shift
}

# list category entries
list() {
    LOGIN="${USERNAME}:${PASSWORD}"
    # get existing urls
    urls=$(curl -sku ${LOGIN} -H 'Content-Type: application/json' -X GET "https://${BIGIP}/mgmt/tm/sys/url-db/url-category/$CATEGORY")
    if [[ "$urls" =~ "401 Unauthorized" ]]; then
        errorhandler "Request failure"
    elif [ "$(echo $urls | jq .code --compact-output)" == 404 ]; then
        errorhandler "Category does not exist"
    fi
    ## normalize and echo url strings
    if [ -z "$urls" ]; then echo "ERROR: Request failure"; else echo -e "$urls" | jq .urls[].name | sed 's/"//g'; fi
}

# list category entries
dump() {
    LOGIN="${USERNAME}:${PASSWORD}"
    # get existing urls
    urls=$(curl -sku ${LOGIN} -H 'Content-Type: application/json' -X GET "https://${BIGIP}/mgmt/tm/sys/url-db/url-category/$CATEGORY")
    if [[ "$urls" =~ "401 Unauthorized" ]]; then
        errorhandler "Request failure"
    elif [ "$(echo $urls | jq .code --compact-output)" == 404 ]; then
        errorhandler "Category does not exist"
    fi
    ## normalize and echo url strings
    if [ -z "$urls" ]; then echo "ERROR: Request failure"; else echo "$urls" | jq .urls[].name | sed 's/"//g' > $FILE ; fi
}

## validate input URLs - input data: the url or file contents, input type: either 'url' or 'file'
urlvalidator() {
    local data="$1"
    local type="$2"
    re='^https?:\/\/([-A-Za-z0-9\*\\+&@#\/%?=~_|!:.,;]*[-A-Za-z0-9\\+&@#\/%=~_|])/$'

    if [ "$type" == "url" ]; then
        if [[ ! "$data" =~ $re ]]; then
            errorhandler "url \"$data\" is not in the correct URL category format: \"http(s)://some.domain/\""
        fi
    elif [ "$type" == "file" ]; then
        while IPS="" read -r p || [ -n "$p" ]
        do
            if [[ ! "$p" =~ $re ]]; then
                errorhandler "url \"$p\" in file \"$data\" is not in the correct URL category format: \"http(s)://some.domain/\""
            fi
        done < $data
    fi
}

# add entries to a category
add() {
    METHOD="PATCH"
    LOGIN="${USERNAME}:${PASSWORD}"
    # get existing urls
    urls=$(curl -sku ${LOGIN} -H 'Content-Type: application/json' -X GET "https://${BIGIP}/mgmt/tm/sys/url-db/url-category/$CATEGORY")
    if [[ "$urls" =~ "401 Unauthorized" ]]; then
        errorhandler "Request failure"
    elif [ "$(echo $urls | jq .code --compact-output)" == 404 ]; then
        METHOD="POST"
    fi
    urls=$(echo $urls |jq .urls --compact-output |sed 's/\[//g' |sed 's/\]//g')

    if [[ -n "$URL" ]]; then
        # single entry
        if [[ "$URL" =~ .*"*".* ]]
        then
            newurl="{\"name\":\"$URL\",\"type\":\"glob-match\"}"
        else
            newurl="{\"name\":\"$URL\",\"type\":\"exact-match\"}"
        fi
    elif [[ -n "$FILE" ]]; then
        # validate the file contents
        if [[ ! -e "$FILE" ]]; then errorhandler "file does not exist"; fi
        urlvalidator "$FILE" "file"

        # multiple entries via file
        while IPS="" read -r p || [ -n "$p" ]
        do
            if [[ "$p" =~ .*"*".* ]]
            then
                myarray+=("{\"name\":\"$p\",\"type\":\"glob-match\"}")
            else
                myarray+=("{\"name\":\"$p\",\"type\":\"exact-match\"}")
            fi
        done < $FILE
        newurl=$(joinByString ${myarray[@]})
        newurl="${newurl:1}"
    fi

    # send payload to update urls
    if [ "$METHOD" == "PATCH" ]; then
        payload="{\"urls\":[${urls},${newurl}]}"
        if [[ -n "$DRYRUN" ]]; then
            echo "curl -sku '${USERNAME}:XXXXXXX' -H 'Content-Type: application/json' -X ${METHOD} \"https://${BIGIP}/mgmt/tm/sys/url-db/url-category/$CATEGORY\" -d '${payload}'"
            exit 0
        else
            ret=$(curl -sku ${LOGIN} -H 'Content-Type: application/json' -X ${METHOD} "https://${BIGIP}/mgmt/tm/sys/url-db/url-category/$CATEGORY" -d "${payload}")
        fi        
    elif [ "$METHOD" == "POST" ]; then
        payload2="{\"name\": \"${CATEGORY}\", \"isCustom\": true, \"displayName\": \"${CATEGORY}\", \"urls\": [${newurl}]}"
        if [[ -n "$DRYRUN" ]]; then
            echo "curl -sku '${USERNAME}:XXXXXXX' -H 'Content-Type: application/json' -X ${METHOD} \"https://${BIGIP}/mgmt/tm/sys/url-db/url-category -d '${payload2}'"
            exit 0
        else
            ret=$(curl -sku ${LOGIN} -H 'Content-Type: application/json' -X ${METHOD} "https://${BIGIP}/mgmt/tm/sys/url-db/url-category" -d "${payload2}")
        fi
    fi
    code=$(echo $ret | jq .code --compact-output)
    if [ "$code" == 400 ]; then errorhandler "$(echo $ret | jq .message)"; fi
}

# remove entries from a category
del() {
    LOGIN="${USERNAME}:${PASSWORD}"
    # get existing urls
    urls=$(curl -sku ${LOGIN} -H 'Content-Type: application/json' -X GET "https://${BIGIP}/mgmt/tm/sys/url-db/url-category/$CATEGORY")
    if [[ "$urls" =~ "401 Unauthorized" ]]; then
        errorhandler "Request failure"
    elif [ "$(echo $urls | jq .code --compact-output)" == 404 ]; then
        errorhandler "Category does not exist"
    fi
    urls=$(echo $urls |jq .urls --compact-output |sed 's/\[//g' |sed 's/\]//g')
    
    if [[ -n "$URL" ]]; then
        # single entry
        if [[ "$URL" =~ .*"*".* ]]
        then
            newurl="{\"name\":\"$URL\",\"type\":\"glob-match\"}"
        else
            newurl="{\"name\":\"$URL\",\"type\":\"exact-match\"}"
        fi
        modurls=`printf '%s\n' "${urls//$newurl/}"`
        payload="{\"urls\":[${modurls}]}"
        payload=`echo ${payload} |sed "s/\[,/\[/;s/,\]/\]/;s/,,/,/"`
    elif [[ -n "$FILE" ]]; then
        # validate the file contents
        if [[ ! -e "$FILE" ]]; then errorhandler "file does not exist"; fi
        urlvalidator "$FILE" "file"

        # ignore delentry and read from FILE
        while IPS="" read -r p || [ -n "$p" ]
        do
            if [[ "$p" =~ .*"*".* ]]
            then
                newurl="{\"name\":\"$p\",\"type\":\"glob-match\"}"
            else
                newurl="{\"name\":\"$p\",\"type\":\"exact-match\"}"
            fi
            urls=`printf '%s\n' "${urls//$newurl/}"`
        done < $FILE
        payload="{\"urls\":[${urls}]}"
        payload=`echo ${payload} |sed 's/\([,]\)\1*/\1/g' | sed 's/\[,/\[/g'`
    fi

    if [[ -n "$DRYRUN" ]]; then
        echo "curl -sku '${USERNAME}:XXXXXXX' -H 'Content-Type: application/json' -X PATCH \"https://${BIGIP}/mgmt/tm/sys/url-db/url-category/$CATEGORY -d '${payload}'"
        exit 0
    else
        ret=$(curl -sku ${LOGIN} -H 'Content-Type: application/json' -X PATCH "https://${BIGIP}/mgmt/tm/sys/url-db/url-category/$CATEGORY" -d "${payload}")
    fi
    code=$(echo $ret | jq .code --compact-output)
    if [ "$code" == 400 ]; then errorhandler "$(echo $ret | jq .message)"; fi
}

# replace entries from a category (overwrite)
repl() {
    LOGIN="${USERNAME}:${PASSWORD}"
    # get existing urls
    urls=$(curl -sku ${LOGIN} -H 'Content-Type: application/json' -X GET "https://${BIGIP}/mgmt/tm/sys/url-db/url-category/$CATEGORY")
    if [[ "$urls" =~ "401 Unauthorized" ]]; then
        errorhandler "Request failure"
    elif [ "$(echo $urls | jq .code --compact-output)" == 404 ]; then
        errorhandler "Category does not exist"
    fi
    
    # read from FILE
    payload=""
    # validate the file contents
    if [[ ! -e "$FILE" ]]; then errorhandler "file does not exist"; fi
    urlvalidator "$FILE" "file"

    while IPS="" read -r p || [ -n "$p" ]
    do
        if [[ "$p" =~ .*"*".* ]]
        then
            newurl="{\"name\":\"$p\",\"type\":\"glob-match\"}"
        else
            newurl="{\"name\":\"$p\",\"type\":\"exact-match\"}"
        fi
        payload+="${newurl}"
    done < $FILE
    payload="{\"urls\":[${payload}]}"
    payload=`echo ${payload} |sed "s/\[,/\[/;s/,\]/\]/;s/,,/,/"`

    if [[ -n "$DRYRUN" ]]; then
        echo "curl -sku '${USERNAME}:XXXXXXX' -H 'Content-Type: application/json' -X PATCH \"https://${BIGIP}/mgmt/tm/sys/url-db/url-category/$CATEGORY -d '${payload}'"
        exit 0
    else
        ret=$(curl -sku ${LOGIN} -H 'Content-Type: application/json' -X PATCH "https://${BIGIP}/mgmt/tm/sys/url-db/url-category/$CATEGORY" -d ${payload}) # > /dev/null 2>&1
    fi
    code=$(echo $ret | jq .code --compact-output)
    if [ "$code" == 400 ]; then errorhandler "$(echo $ret | jq .message)"; fi
}

## validate the input switches
process_handler() {
    # validate required arguments (--cat, --bigip, --user)
    if [ -z "$CATEGORY" ]; then 
        errorhandler "--cat CATEGORY must be specified"
    elif [ -z "$BIGIP" ]; then 
        errorhandler "--bigip BIG-IP IP address or hostname must be specified"
    elif [ -z "$USERNAME" ]; then 
        errorhandler "--user USERNAME must be specified"
    fi

    ## validate commands and required options
    if [[ -z "$COMMAND" ]]; then
        errorhandler "execution requires a command (--add, --del, or --repl)"
    elif [[ ("$COMMAND" == "add") && ((-z "$URL") && (-z "$FILE")) ]]; then
        errorhandler "--add requires either a single --url <url> or --file <file> as input"
    elif [[ ("$COMMAND" == "del") && ((-z "$URL") && (-z "$FILE")) ]]; then
        errorhandler "--del requires either a single --url <url> or --file <file> as input"
    elif [[ ("$COMMAND" == "repl") && (-z "$FILE") ]]; then
        errorhandler "--repl requires a --file <file> as input"
    elif [[ ("$COMMAND" == "dump") && (-z "$FILE") ]]; then
        errorhandler "--dump requires a --file <file> as input"
    fi

    # execute functions
    # echo -n Password:
    # read -s PASSWORD
    read -s -p "Password: " PASSWORD
    if [ "$COMMAND" == "list" ]; then list
    elif [ "$COMMAND" == "dump" ]; then dump
    elif [ "$COMMAND" == "add" ]; then add
    elif [ "$COMMAND" == "del" ]; then del
    elif [ "$COMMAND" == "repl" ]; then repl; fi
}

# parse input arguments
main() {
    while (( ${#} )); do
        case "${1}" in
            --help|-h)
              help >&2
              exit 0;;
            
            --cat|-c)
              shift 1
              CATEGORY="${1}"
              ;;

            --bigip|-b)
              shift 1
              BIGIP="${1}"
              ;;

            --file|-f)
              shift 1
              FILE="${1}"
              ;;
            
            --url|-u)
              shift 1
              URL="${1}"
              urlvalidator "$URL" "url"
              ;;
            
            --dryrun)
              DRYRUN=true
              ;;

            --list|-l)
              COMMAND=list
              ;;
            
            --dump|-x)
              COMMAND=dump
              ;;

            --add|-a)
              COMMAND=add
              ;;
            
            --del|-d)
              COMMAND=del
              ;;

            --repl|-r)
              COMMAND=repl
              ;;

            --user|-i)
              shift 1
              USERNAME="${1}"
              ;;
            
            *)
              echo "Invalid option: ${1}"
              help >&2
              exit 1;;
        esac
    shift 1
    done

    process_handler
}

main "${@:-}"
