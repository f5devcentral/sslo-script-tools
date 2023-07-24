## Detecting Generative AI tools with SSL Orchestrator

#### This tool creates a custom URL category on the F5 BIG-IP, and populates that with known generative AI URLs. Employ the custom category in an SSL Orchestrator security policy rule to categorize on known generative AI tools.

-----------------

* **Step 1**: Create the custom URL category and populate with known AI URLs - Access the BIG-IP command shell and run the following command. This will initiate a script that creates and populates the URL category:

  ```
  curl -s https://raw.githubusercontent.com/kevingstewart/sslo-generative-ai-categories/main/sslo-create-genai-category.sh |bash
  ```

* **Step 2**: Create an SSL Orchestrator policy rule to use this data - The above script creates/re-populates a custom URL category named **SSLO_GENERATIVE_AI_CHAT**, and in that category is a set of known generative AI URLs. To use, navigate to the SSL Orchestrator UI and edit a Security Policy. Click add to create a new rule, use the "Category Lookup (All)" policy condition, then add the above URL category. Set the Action to "Allow", SSL Proxy Action to "Intercept", and Service Chain to whatever service chain you've already created.
