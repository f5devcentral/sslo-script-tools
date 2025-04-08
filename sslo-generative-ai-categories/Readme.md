## Detecting Generative AI tools with SSL Orchestrator

#### This simple script creates a custom URL category on the F5 BIG-IP and populates with known generative AI URLs. You can then use this custom category in an SSL Orchestrator security policy rule to categorize on known generative AI tools.

-----------------
To deploy:

* **Step 1**: Create the custom URL category and populate with known AI URLs - Access the BIG-IP command shell and run the following command. This will initiate a script that creates and populates the URL category:

  ```
  curl -s https://raw.githubusercontent.com/f5devcentral/sslo-script-tools/main/sslo-generative-ai-categories/sslo-create-ai-category.sh |bash
  ```

* **Step 2**: Create an SSL Orchestrator policy rule to use this data - The above script creates/re-populates a custom URL category named **SSLO_GENERATIVE_AI_CHAT**, and in that category is a set of _known_ generative AI URLs. To use, navigate to the SSL Orchestrator UI and edit a Security Policy. Click **Add** to create a new policy rule, use the "Category Lookup (All)" policy condition, then add the above URL category. Set the policy rule actions accordingly:

  * **Action**: set this to Allow or Block depending on your local requirements
  * **SSL Proxy Action**: set this to Intercept to enable decryption and inspection
  * **Service Chain**: apply to whatever service chain you've already created
 

<br />
<br />

To log category matches, edit the SSL Orchestrator Topology, and under Log Settings, set **SSL Orchestrator Generic** to "Information". This will enable a Traffic Summary log entry for each flow. By default this goes to local Syslog, but can be pushed to a remote collector by adjusting the Log Publisher. The following example Traffic Summary log entry lists both the policy rule match (GenerativeAI_Detect) and the URL category (/Common/SSLO_GENERATIVE_AI_CHAT):

<br />

```
# tail -f /var/log/apm

Jul 24 07:24:54 sslo1.f5labs.com info tmm3[10913]: 01c40000:6: /Common/sslo_demo.app/sslo_demo_accessProfile:Common:55e3d724: /Common/sslo_demo.app/sslo_demo-in-t-4 Traffic summary - tcp 10.1.10.50:45896 -> 13.107.213.70:443 clientSSL: TLSv1.2 ECDHE-RSA-AES128-GCM-SHA256 serverSSL: TLSv1.2 ECDHE-RSA-AES128-GCM-SHA256 L7 https (openai.com) decryption-status: decrypted duration: 138 msec service-path: ssloSC_all_services client-bytes-in: 1565 client-bytes-out: 99621 server-bytes-in: 103236 server-bytes-out: 2452 client-tls-handshake: completed server-tls-handshake: completed reset-cause: 'NA' policy-rule: 'GenerativeAI_Detect' url-category: /Common/SSLO_GENERATIVE_AI_CHAT ingress: /Common/client-vlan egress: /Common/outbound-vlan
```

<br />

-----------------
**Note**: Officially, ChatGPT through SSL Orchestrator requires HTTP/2. The **Proxy ALPN** option was added in 9.0: https://clouddocs.f5.com/sslo-deployment-guide/sslo-09/chapter1/page1.02.html. 

-----------------
**Last Updated**: 08 April 2025

Collected from various sources:
- https://aitoolsdirectory.com/
- https://github.com/filipecalegario/awesome-generative-ai
- https://github.com/steven2358/awesome-generative-ai
- https://doc.clickup.com/25598832/d/h/rd6vg-14247/0b79ca1dc0f7429/rd6vg-12207
