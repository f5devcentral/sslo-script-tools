# F5 SSL Orchestrator Layered Architecture Configuration
# Explicit Proxy Configuration Use Cases
This section defines use cases specific to an explicit forward proxy implementation using the layered architecture

## Encrypted Traffic to an HTTP Proxy Service:
SSL Orchestrator employs "flow signaling" to maintain traffic context through the dynamic service chain. As a flow leaves the BIG-IP for an inline security service, its flow information is recorded (src+dst IP:port) so that when it returns from the service, context can be re-established. An inline HTTP proxy service, however, will always minimally change the source port, thus breaking the flow signal. For this reason, and to support HTTP proxy services in the dynamic service chain, SSL Orchestrator uses an HTTP header signal through this device type. This also requires that signaling through a proxy service can only happen for unencrypted/decrypted HTTP traffic. As an HTTP header cannot be injected into TLS bypassed connections, SSL Orchestrator will bypass any proxy service in the service chain for TLS bypassed traffic. 

The following use case describes an alternate method for passing encrypted traffic to an HTTP proxy service, by using the Internal Layered Architecture and egress proxy chaining. The layered steering VIP, per policy, will steer traffic to an internal TLS bypass SSL Orchestrator topology. That topology will be configured to proxy chain out to the HTTP proxy service (looping back into the service chain). A separate "control channel" virtual server is then established to catch the HTTPS traffic leaving the proxy service, to send direct to egress.

![SSL Orchestrator Internal Layered Architecture](../../images/sslo-encrypted-traffic-to-proxy.png)

Traffic destined for TLS interception is steered to an intercept topology by the layered virtual server, and then egresses the normal routed path. Decrypted traffic to the service chain will flow through all of the defined services here, including the proxy service. Traffic destined for TLS bypass is steered to the bypass topology, which is then configured to proxy chain to the proxy service, looping back into the service chain. The SSL Orchestrator service chain would not accept this traffic, so a separate "control channel" virtual catches any HTTPS (port 443) traffic leaving the proxy service, directing that to the routed egress path.

The steps to configure this are as follows:

- Deploy an Internal Layered Architecture "Proxy in Back" configuration
- Create any SSL Orchestrator TLS intercept topologies as required, define services and service chains
- Create a new proxy service pool
- Create a TLS bypass topology and configure Proxy Connect to the proxy service
- Create a service control channel virtual server

### Deploy an Internal Layered Architecture "Proxy in Back" configuration
- Use the explicit proxy "Proxy in Back" configuration, as detailed on the main page, to establish an explicit proxy internal layered architecture.


### Create any SSL Orchestrator TLS intercept topologies as required, define services and service chains
- In the SSL Orchestrator UI, create any internal TLS intercept topologies as required. Define the services and service chains here.


### Create a new proxy service pool
- Under Local Traffic -> Pools, create a new pool that points to the explicit proxy service listener IP:port. This will be the same IP and port defined for the proxy service in the SSL Orchestrator service configuration.


### Create a TLS bypass topology and configure Proxy Connect to the proxy service
- In the SSL Orchestrator UI, create a TLS bypass topology. On the Security Policy page, enable **Proxy Connect** and select the new proxy service pool.


### Create a service control channel virtual server
- Under Local Traffic -> Virtual Servers, create a new virtual server:
  - Source: 0.0.0.0/0
  - Destination: 0.0.0.0/0
  - Port: 443
  - VLAN: enable and select the proxy service's "from-service" VLAN as defined in the SSL Orchestrator service configuration
  - Address Translation: disabled
  - Port Translation: disabled
  - Pool: select an existing or create a new pool that points to the routed gateway (the same that the TLS intercept topology uses)


Note that the control channel virtual service listens on the proxy service's "from-service" VLAN. SSL Orchestrator defines a wildcard 0.0.0.0/0:0) virtual server on this same VLAN, so the control channel listens on a **more specific** traffic flow (port 443). Any traffic leaving the HTTP proxy service inside the service chain of a TLS intercept topology would normally be HTTP port 80. You don't have use a specific port here though. In fact, if your proxy device is capable of enabling and disabling source address translation (i.e. SNAT, or "client IP reflection") based on local policy, you could configure that proxy device to SNAT (use its own IP for HTTPS traffic), and not SNAT (enable client IP reflection) for HTTP traffic. In this case, the control channel virtual server could be configured to instead listen on the proxy service's self-IP as the source of traffic. This would also be useful for allowing the HTTP proxy service to reach out to Internet sites (from its own IP address), for example to reach a licensing or subscription update service.





