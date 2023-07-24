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
To log category matches, set the Topology logging to Summary.

-----------------
**Note**: Officially, ChatGPT through SSL Orchestrator requires HTTP/2. The **Proxy ALPN** option was added in 9.0: https://clouddocs.f5.com/sslo-deployment-guide/sslo-09/chapter1/page1.02.html. 
