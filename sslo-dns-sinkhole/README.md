# DNS Sinkholing with SSL Orchestrator

#### This tool creates a configuration on the F5 BIG-IP to support DNS sinkholing and decrypted blocking page injection with SSL Orchestrator.

-----------------

DNS sinkholing is a method to divert traffic away from its intended target (divert to something). Contrast this with DNS blackholing, which causes all traffic to a target to be dropped (divert to nothing). Both of these security functions are performed with DNS record manipulation. With blackholing, an NXDOMAIN record is typically returned. With sinkholing, a separate target address is returned from the resolution query, often to a site that presents a blocking page. Sinkholing works well for cleartext traffic to enable injection of a blocking page, but under normal conditions a TLS client would receive the blocking page with a certificate warning, as the certificate received would not match the site requested. The following integration enables SSL Orchestrator for the purpose of generating (forging) a server certificate that is both locally trusted and matches the URL requested by the client. The configuration relies on two components:

* A **sinkhole internal** virtual server with client SSL profile to host a sinkhole certificate and key. This is a certificate with empty Subject field used as the origin for forging a trusted certificate to the internal client. 

* An **SSL Orchestrator** outbound L3 topology that is modified to accept traffic on a specific client-facing IP:port and points to the internal virtual server. When an internal client makes a request to this virtual server, SSL Orchestrator fetches the origin "sinkhole" certificate, forges a new local certificate, and auto-injects a subject-alternative-name into the forged certificate to match the client's request. An iRule is added to insert an HTTP/HTML blocking page response on the explicitly decrypted traffic.

DNS sinkholing to a blocking page effectively relies on two separate technologies: the DNS security solution itself - the thing that manipulates the client's DNS request for the purpose of preventing access to suspected malicious sites, and the sinkhole target - the thing that presents a valid certificate to the client and injects the blocking response. This integration specifically addresses the latter. The former is reasonably out-of-scope, and could be provided in any number of ways, as discussed below in the **Testing** topic.

-----------------

### Configuration: Sinkhole Internal

*Note: Minimum BIG-IP requirement for this solution is version 16.x.*

To create the **sinkhole internal** virtual server configuration:

* **Optional easy-install step**: The following Bash script builds all of the necessary objects for the internal virtual server configuration. You can either use this to handle steps 1 to 4 automatically, or follow the steps below to create these manually. Step 5 must be done manually.

  ```
  curl -s https://raw.githubusercontent.com/f5devcentral/sslo-script-tools/main/sslo-dns-sinkhole/create-sinkhole-internal-config.sh | bash
  ```

* **Step 1: Create the sinkhole certificate and key** The sinkhole certificate is specifically crafted to contain an empty Subject field. SSL Orchestrator is able to dynamically modify the subject-alternative-name field in the forged certificate, which is the only value of the two required by modern browsers.

  ```
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
  extendedKeyUsage=serverAuth,clientAuth")
  ```

* **Step 2: Install the sinkhole certificate and key to the BIG-IP** Either manually install the new certificate and key to the BIG-IP, or use the following TMSH transaction:
  ```
  (echo create cli transaction
  echo install sys crypto key sinkhole-cert from-local-file "$(pwd)/sinkhole.key"
  echo install sys crypto cert sinkhole-cert from-local-file "$(pwd)/sinkhole.crt"
  echo submit cli transaction
  ) | tmsh
  ```

* **Step 3: Create a client SSL profile that uses the sinkhole certificate and key** Either manually create a client SSL profile and bind the sinkhole certificate and key, or use the following TMSH command:
  ```
  tmsh create ltm profile client-ssl sinkhole-clientssl cert sinkhole-cert key sinkhole-cert > /dev/null
  ```

* **Step 4: Create the sinkhole "internal" virtual server** This virtual server simply hosts the client SSL profile and sinkhole certificate that SSL Orchestrator will use to forge a blocking certificate.

  - Type: Standard
  - Source Address: 0.0.0.0/0
  - Destination Address/Mask: 0.0.0.0/0
  - Service Port: 9999 (does not really matter)
  - HTTP Profile (Client): http
  - SSL Profile (Client): the sinkhole client SSL profile
  - VLANs and Tunnel Traffic: select "Enabled on..." and leave the Selected box empty

  or use the following TMSH command:

  ```
  tmsh create ltm virtual sinkhole-internal-vip destination 0.0.0.0:9999 profiles replace-all-with { tcp http sinkhole-clientssl } vlans-enabled
  ```

* **Step 5: Create the sinkhole target iRule** This iRule will be placed on the SSL Orchestrator topology to steer traffic to the sinkhole internal virtual server. Notice the contents of the HTTP_REQUEST event. This is the HTML blocking page content. Edit this at will to meet your local requriements.

  ```
  when CLIENT_ACCEPTED {
      virtual "sinkhole-internal-vip"
  }
  when CLIENTSSL_CLIENTHELLO priority 800 {
      if {[SSL::extensions exists -type 0]} {
          binary scan [SSL::extensions -type 0] @9a* SNI
      }
  
      if { [info exists SNI] } {
          SSL::forward_proxy extension 2.5.29.17 "critical,DNS:${SNI}"
      }
  }
  when HTTP_REQUEST {
      HTTP::respond 403 content "<html><head></head><body><h1>Site Blocked!</h1></body></html>"
  }
  ```

-----------------

### Configuration: Sinkhole External (SSL Orchestrator)

To create the **SSL Orchestrator** outbound L3 topology configuration, in the SSL Orchestrator UI, create a new Topology. Any section not mentioned below can be skipped.

* **Topology Properties**

  - Protocol: TCP
  - SSL Orchestrator Topologies: select L3 Outbound

* **SSL Configuration**

  - Click on "Show Advanced Setting"
  - CA Certificate Key Chain: select the correct client-trusted internal signing CA certificate and key
  - Expire Certificate Response: Mask
  - Untrusted Certificate Response: Mask

* **Security Policy**

  - Delete the Pinners_Rule

* **Interception Rule**

  - Destination Address/Mask: enter the client-facing IP address/mask. This will be the address sent to clients from the DNS for the sinkhole
  - Ingress Network/VLANs: select the client-facing VLAN
  - Protocol Settings/SSL Configurations: ensure the previously-created SSL configuration is selected

Ignore all other settings and **Deploy**. Once deployed, navigate to the Interception Rules tab and edit the new topology interception rule.

  - Resources/iRules: add the **sinkhole-target-rule** iRule

Ignore all other settings and **Deploy**.

-----------------

### Testing

The easiest way to **test** this solution is to create an **/etc/hosts** file entry on a client for some Internet site (ex. www.example.com) and point that to your SSL Orchestrator (sinkhole external) listening IP. Attempt to access that site via HTTPS and HTTP from a browser on this client. The blocking page content will be returned along with a valid locally-issued server certificate. This minimally tests a single client through local DNS manipulation. To expand on this idea into more practical implementations, consider the following:

* Any proper DNS security solution can work here, from any security vendor, assuming it supports sinkholing (returning a specified address to clients for blocked sites).

* For environments that allow/enable DNS-over-HTTPS (DoH) and/or DNS-over-TLS (DoT) to third party DoH/DoT resolvers (ex. Cloudflare), a modification of the [SSL Orchestrator DNS-over-HTTPS Detection](https://github.com/f5devcentral/sslo-script-tools/tree/main/sslo-dns-over-https-detection) use case could be employed. This is an SSL Orchestrator use case for the detection, decryption, and management of outgoing DoH/DoT traffic. The modified DoH/DoT detection iRule is provided in **this** repository: **sslo-doh-logging.tcl**. Add this iRule to the BIG-IP, then add to the Interception Rule of a standard outbound L3 SSL Orchestrator topology. The local version of this iRule adds support for DNS sinkhole. In the RULE_INIT section, a new **set static::SINKHOLE_IP** variable exists. To enable sinkholing, plug the local sinkhole IP address into this variable.

* Injecting a static HTML response blocking page is just one option among many. You could, for example, issue a redirect instead of static HTML, and send the client to a more formal "splash page". This redirect could inject additional metadata to provide to the splash page. For example:

```
when HTTP_REQUEST {
  HTTP::redirect "https://splash.f5labs.com/?cats=gis-dns-block&client_ip=[IP::client_addr]&type=dns&url=[URI::encode [b64encode [HTTP::host]]"
}
```







  
