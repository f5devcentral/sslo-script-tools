# SSL Orchestrator DNS-over-HTTPS Detection
Set of iRule tools to add DoH detection to SSL Orchestrator

Current version: 3 (Oct 2022)
Includes support for DoT handling and minor bugfixes

## Version support
These iRules work on all modern versions of BIG-IP (14.1+) and SSL Orchestrator (5.0+)

## Description
Based on RFC8484, DNS-over-HTTPS (DoH) is a method of securely conveying DNS requests/responses over encrypted HTTPS. While DoH is intended to provide additional privacy (i.e. DNS traffic is not protected from eavesdropping), it can have other serious implications as it also potentially masks malware command-and-control. In the absence of running a local DoH-capable DNS resolver, detection of DoH traffic minimally requires decryption and inspection. This repository provides a set of iRules that can be attached to an SSL Orchestrator configuration to provide the following DoH controls:

- **DoH Detection and Blocking**: This simply identifies any DoH request traffic, in any of the three DoH formats (Wireframe GET/POST and JSON) and sends a reject. A DoH-cable browser that receives reject on DoH request will revert to normal DNS.

- **DoH Detection and Logging**: This identifies DoH request traffic, and can:
  - Parse the query name and type (A, AAAA, TXT, etc.) for local and remote high-speed logging
  - Enable a DoH blackhole response for A, AAAA and TXT requests based on a URL category match (of the requested name)

------------------------------

## Installation
Installation is as simple as adding the respective iRule to an SSL Orchestrator topology. 

  - Under Local Traffic -> iRules in the BIG-IP UI, import the required iRule.
  - In the SSL Orchestrator UI, under the Interception Rules tab, click on the interception rule to edit (typically ending with "-in-t"), and at the bottom of this configuration page, add the iRule and then (re)deploy.
  - If using the DoH detection and logging iRule, additional configuration is required (see below).

------------------------------

## Configuration
Configuration in the DoH detection and logging iRule is performed through a set of static variables at the top of the rule:

  - **static::LOCAL_LOG**: (off=0, on=1) enables or disables local Syslog logging. It is recommended to disable this unless troubleshooting.

  - **static::HSL**: (off="none", on=[HSL pool name]) enables or disables remote high-speed logging (HSL). To create an HSL pool:
    - Under Local Traffic -> Pools, create a pool that points to the remote Syslog (using something on port 514).
    - Enable HSL logging in the iRule by specifying the pool name in the static variable.

  - **static::URLDB_LICENSED**: (off=0, on=1) the DoH detection iRule can use URL categorization to perform DoH blackholing. If subscription-based URLDB is licensed and provisioned, you can enable this (set to 1) to search the URLDB categories. Otherwise, set to 0 and continue to use custom URL categories.

  - **static::BLACKHOLE_URLCAT**: (off=empty, on=[list of category names]) if DoH blackholing is desired, add the list of URL categories to search here. This can be a combination of URLDB categories and/or custom URL categories. Leave it empty to disable URL categorization. For example:
  
      ```
      set static::BLACKHOLE_URLCAT {
         "/Common/Advanced_Malware_Command_and_Control"
         "/Advanced_Malware_Payloads"
         "/Common/Spyware_and_Adware"
         "/Comomn/SPAM_URLs"
         "/Common/Financial_Data_and_Services"
         "/Commmon/my_custom_url_category"
      }
      ```
      
      You can get the list of URLDB categories with this command:
      
      `tmsh list sys url-db url-category |grep "sys url-db url-category " |awk -F" " '{print $4}'`
  
  - **static::BLACKHOLE_RTYPE_A**: (off=0, on=1) enables or disables blackholing of DoH A record requests. This will send a response with 199.199.199.199. When the client attempts to connect to this IP through the SSL Orchestrator topology, the connection will be rejected.
  
  - **static::BLACKHOLE_RTYPE_AAAA**: (off=0, on=1) enables or disables blackholing of DoH AAAA record requests. This will send a response with 0:0:0:0:0:ffff:c7c7:c7c7. When the client attempts to connect to this IP through the SSL Orchestrator topology, the connection will be rejected.
  
  - **static::BLACKHOLE_RTYPE_TXT**: (off=0, on=1) enables or disables blackholing of DoH TXT record requests. This will send a response with generic "v=spf1 -all".
  
  - **static::dns_codes**: This value does not need to be edited, but contains an array of type:value values for different record types. This array is used to identify record types (ex. A, AAAA, TXT, CNAME) for logging.
