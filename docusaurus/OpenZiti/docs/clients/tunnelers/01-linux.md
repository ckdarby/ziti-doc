---
title: Linux
---
# Linux

### The Tunneller CLI

`ziti-edge-tunnel` is the general purpose tunneller CLI and can also run as a systemd daemon. For the best overall experience, please use the preferred tunneller `ziti-edge-tunnel` described here.

The purpose of the tunneller is to configure host access. This means all users and all processes on the host will share the same level of access. This is accomplished by configuring the OS to have an on-board OpenZiti DNS nameserver and IP routes for authorized OpenZiti Services.

### Installation and Upgrade

:::note
It is not necessary to manually enroll the identity when using the RPM or DEB package. Just install the token in the identities directory and it will be enrolled when you start the daemon.
:::

#### Installing the DEB

1. Run the script below to import the signing key, add a package source to the list, update sources, and install ziti-edge-tunnel.
1. Install an enroll token JWT file or identity config JSON file in `/opt/openziti/etc/identities`.
1. Run `systemctl start ziti-edge-tunnel.service`. The service needs to be restarted if the contents of the identities directory change.

##### Ubuntu Jammy 22.04

```bash
curl -sSLf https://raw.githubusercontent.com/openziti/ziti-tunnel-sdk-c/main/package-repos.gpg \
| gpg --dearmor \
| sudo tee /usr/share/keyrings/openziti.gpg >/dev/null
echo 'deb [signed-by=/usr/share/keyrings/openziti.gpg] https://packages.openziti.org/zitipax-openziti-deb-stable jammy main' \
| sudo tee /etc/apt/sources.list.d/openziti.list >/dev/null
sudo apt update
sudo apt install ziti-edge-tunnel
```

##### Ubuntu Focal 20.04, Bionic 18.04, Xenial 16.04, Trusty 14.04

The script is the same as Jammy for these older Ubuntu releases, but you must substitute the correct Ubuntu release code name e.g. "focal" in place of "jammy" in the apt sources file.

##### Debian GNU/Linux

The script is the same as Ubuntu Jammy for Debian releases, but you should substitute the youngest Ubuntu release code name e.g. "focal" that is older than your release of Debian in place of "jammy" in the apt sources file. For simplicity's sake, the Ubuntu 18.04 "bionic" build is broadly compatible with modern Debian releases.

#### Installing the RPM

1. Create a repo file like `/etc/yum.repos.d/openziti.repo` matching the appropriate example below for your OS.
1. Run `yum update` to refresh your repodata cache. Optionally, you may wish to also install all available updates.
1. Run `yum install ziti-edge-tunnel` to install the RPM.
1. Install an enroll token JWT file or identity config JSON file in `/opt/openziti/etc/identities`.
1. Run `systemctl start ziti-edge-tunnel.service`. The service needs to be restarted if the contents of the identities directory change.

##### RHEL, CentOS, and Rocky Linux

```ini
[OpenZiti]
name=OpenZiti
baseurl=https://packages.openziti.org/zitipax-openziti-rpm-stable/redhat$releasever/$basearch
enabled=1
gpgcheck=0
gpgkey=https://packages.openziti.org/zitipax-openziti-rpm-stable/redhat$releasever/$basearch/repodata/repomd.xml.key
repo_gpgcheck=1
```

##### Fedora

```ini
[OpenZiti]
name=OpenZiti
baseurl=https://packages.openziti.org/zitipax-openziti-rpm-stable/redhat8/$basearch
enabled=1
gpgcheck=0
gpgkey=https://packages.openziti.org/zitipax-openziti-rpm-stable/redhat8/$basearch/repodata/repomd.xml.key
repo_gpgcheck=1
```

##### Amazon Linux

```ini
[OpenZiti]
name=OpenZiti
baseurl=https://packages.openziti.org/zitipax-openziti-rpm-stable/redhat7/$basearch
enabled=1
gpgcheck=0
gpgkey=https://packages.openziti.org/zitipax-openziti-rpm-stable/redhat7/$basearch/repodata/repomd.xml.key
repo_gpgcheck=1
```

#### Binary

[The latest binary release](https://github.com/openziti/ziti-tunnel-sdk-c/releases/latest/) of `ziti-edge-tunnel` is distributed as an executable for amd64, arm, arm64 architectures. The upgrade procedure is identical to the installation procedure.

```bash
# shell script illustrating the steps to install or upgrade ziti-edge-tunnel
wget -q "https://github.com/openziti/ziti-tunnel-sdk-c/releases/latest/download/ziti-edge-tunnel-Linux_$(uname -p).zip" \
  && unzip ./ziti-edge-tunnel-Linux_$(uname -p).zip \
  && rm ./ziti-edge-tunnel-Linux_$(uname -p).zip \
  && chmod -c +x ./ziti-edge-tunnel \
  && ./ziti-edge-tunnel version
```

##### Enroll Before You Run

You will need the token file or its contents to enroll. Enrollment is the act of exchanging the token for an identity that is to be permanently installed in the filesystem.

[Here's a link to the article about enrolling](../../identities/enrolling.md)

### Global Options


```bash
# Load a single identity.
--identity <identity>
```

```bash
# Load all identities in a dir, ignoring files with a .bak or .original filename suffix.
--identity-dir <dir>
```

```bash
# Set log level, higher is more verbose (default level 3 means INFO).
--verbose N
```

```bash
# Set service polling interval in seconds (default 10).
--refresh N
```

### `run` Mode

`ziti-edge-tunnel run` provides a transparent proxy and nameserver. The nameserver may be configured to be authoritative (the default) or recursive with a command-line option. The OS is automatically configured to treat the nameserver as primary. You may inspect the resulting configuration with these commands.

```bash
resolvectl dns     # inspect the association of tun device and nameserver
resolvectl domain  # inspect the configuration of query routing domains
```

If any interfaces have a wildcard routing domain configured, `ziti-edge-tunnel` will also configure its tun with a wildcard routing domain. If no other interface has a wildcard routing domain configured, neither will the `ziti-edge-tunnel` tun.

```bash
# Specify the tun interface address and the subnet to which Service domain names are resolved (default 100.64.0.1/10). The nameserver address is always the tun interface address +1, default is 100.64.0.2.
--dns-ip-range <ip range>
```

#### How does `ziti-edge-tunnel run` configure nameservers?

`ziti-edge-tunnel run` provides a built-in nameserver that will answer queries that exactly match authorized OpenZiti services' intercept domain names, and will respond with a hard-fail `NXDOMAIN` code if the query does not match an authorized service.

You may enable DNS recursion by specifying an upstream nameserver to answer queries for other domain names that are not services' intercept domain names: `ziti-edge-tunnel run --dns-upstream 208.67.222.222`.

`ziti-edge-tunnel` uses the `libsystemd` D-Bus RPC client and will try to configure the OS's resolvers with `systemd-resolved`. If that's not possible for any reason then `ziti-edge-tunnel run` will fall back to shell commands like `resolvectl`. If `resolvectl` fails then `ziti-edge-tunnel run` will attempt to modify `/etc/resolv.conf` directly to install the built-in nameserver as the primary resolver.

If the DNS record exists it returns the answer and sets query status to `NO_ERROR`. If it does not exist then it sends the query to an upstream DNS server if configured. Otherwise, it sets the query status to `REFUSE`. This implies that the caller *should* keep trying to resolve the domain name with other nameservers.

#### System Requirements For Mode `run`

`ziti-edge-tunnel run` requires elevated privileges for managing the `/dev/net/tun` device, running `resolvectl` to assign nameservers and domain routes to the tun interface, and running `ip route` to manage IP routes. This requires running as root because `setcaps` are not inherited in all of these cases, even when the inherit bit is set.

### `run-host` Mode

`ziti-edge-tunnel run-host` is a mode for hosting (listening) for services which does provide service intercepts or DNS. Services configured for 'Bind' will be hosted by the tunneller.

#### System Requirements For Mode `run-host`

`ziti-edge-tunnel run-host` does not require elevated privileges or the above device or socket, only network egress to the servers for which it is hosting Services.

### Specialized Tunneller Alternatives

There are also a couple of more specialized tunneling apps. Please use the preferred tunneller `ziti-edge-tunnel` described above if possible.

1. `ziti-tunnel` has the unique capability of an opaque, raw TCP proxy in addition to some redundant capabilities deprecated by the preferred, general purpose tunneller described above: `ziti-edge-tunnel`.
1. `ziti-router` has an optional `ziti-tunnel` feature built-in that may be enabled when an Edge Router is first created.

The configuration and behavior of these two tunneller alternatives are identical and so are discussed as one for the remainder of this article. The tunneller is capable of operating in transparent proxy (`tproxy`), opaque proxy (`proxy`), and host (`host`) modes, discussed immediately below.

### tproxy

Typically you will run `ziti-tunnel tproxy`. This is the transparent proxy mode that uses IPtables rules to intercept traffic intended for OpenZiti Services. In this mode `ziti-tunnel` will also serve as an OpenZiti nameserver. You must configure the OS with that nameserver as the primary resolver. The nameserver will only answer queries for which it is authoritative i.e. OpenZiti Services' domain names, and so you will also need a secondary, recursive resolver.

```bash
# You must have the IPtables kernel module installed.
$ lsmod | grep ip_tables
ip_tables              32768  5 iptable_filter,iptable_security,iptable_raw,iptable_nat,iptable_mangle
```

`ziti-tunnel` manipulates routing tables and IPtables rules when using the tproxy
intercept mode. The `NET_ADMIN` Linux capability is required for these actions. The
usage example here runs ziti-tunnel with sudo as a convenient way to gain
that privilege:

```bash
$ sudo ziti-tunnel --identity ziti.json tproxy
[   0.000]    INFO ziti/tunnel/intercept/tproxy.New: tproxy listening on 127.0.0.1:33355
[   0.010]    INFO ziti/tunnel/dns.NewDnsServer: starting dns server...
[   2.018]    INFO ziti/tunnel/dns.NewDnsServer: dns server running at 127.0.0.1:53
[   2.018]    INFO ziti/tunnel/dns.(*resolver).AddHostname: adding ziti-tunnel.resolver.test = 19.65.28.94 to resolver
[   2.033]    INFO ziti/tunnel/dns.(*resolver).RemoveHostname: removing ziti-tunnel.resolver.test from resolver
[   2.096]    INFO ziti/tunnel/cmd/ziti-tunnel/subcmd.updateServices: starting tunnel for newly available service wttr.in
[   2.290]    INFO ziti/tunnel/dns.(*resolver).AddHostname: adding wttr.in = 5.9.243.187 to resolver
[   2.300]    INFO ziti/tunnel/cmd/ziti-tunnel/subcmd.updateServices: service wttr.in not hostable
[   2.300]    INFO ziti/tunnel/cmd/ziti-tunnel/subcmd.updateServices: starting tunnel for newly available service ssh-local
[   2.570]    INFO ziti/tunnel/dns.(*resolver).AddHostname: adding local.io = 169.254.1.1 to resolver
```

The tproxy intercept mode creates a network listener that accepts connections at a
randomly selected port on the loopback interface. Intercepted ziti service traffic
directed to the listener by two mechanisms:

* Firewall Rules (iptables)

    The TPROXY iptables target is the primary intercept mechanism used by the tproxy
    intercept mode. The TPROXY target essentially sends packets to a local listener
    without actually modifying the packet's destination address fields. See
    https://www.kernel.org/doc/Documentation/networking/tproxy.txt and
    `iptables-extensions(8)` for more details on the TPROXY target.

    First, the tproxy interceptor links a new iptables chain to the PREROUTING chain:

    ```bash
    $ sudo iptables -nt mangle -L PREROUTING | grep NF-INTERCEPT
    NF-INTERCEPT  all  --  0.0.0.0/0            0.0.0.0/0
    ```

    Then it creates rules in the new chain for each intercepted service. You can view
    the tproxy rules in play:

    ```bash
    $ sudo iptables -nt mangle -L NF-INTERCEPT
    Chain NF-INTERCEPT (1 references)
    target     prot opt source               destination         
    TPROXY     tcp  --  0.0.0.0/0            5.9.243.187          /* wttr.in */ tcp dpt:443 TPROXY redirect 127.0.0.1:33355 mark 0x1/0x1
    TPROXY     tcp  --  0.0.0.0/0            169.254.1.1          /* ssh-local */ tcp dpt:22 TPROXY redirect 127.0.0.1:33355 mark 0x1/0x1
    TPROXY     tcp  --  0.0.0.0/0            1.2.3.4              /* netcat */ tcp dpt:22169 TPROXY redirect 127.0.0.1:33355 mark 0x1/0x1
    ```

    Packets with a destination address that matches the intercept address of a Ziti
    service are directed to ziti-tunnel's network listener (127.0.0.1:33355 in the
    examples above). This effectively enables `ziti-tunnel` to capture packets that
    are destined for any address using a single listener (and a single port).

    NOTE: _netfilter_ rules were considered when implementing ziti-tunnel's tproxy
    intercept mode. _netfilter_ is a slightly more modern than _iptables_ and has
    a supported netlink API for manipulating rules without "shelling out" to the
    `iptables` command line utility. _netfilter_ was ultimately abandoned because
    netfilter tproxy support requires kernel configuration options (`CONFIG_NFT_TPROXY`,
    `CONFIG_NFT_SOCKET`) that are not enabled in the default kernels of many common
    Linux distributions.

* Local Routes

    The TPROXY target is only valid in the PREROUTING iptables chain, which is
    traversed by incoming packets that were routed to the host over the network. A
    _local_ route is necessary in order to get locally generated packets to traverse
    the PREROUTING chain:

    ```bash
    $ ip route show table local
    local 1.2.3.4 dev lo proto kernel scope host src 1.2.3.4
    local 5.9.243.187 dev lo proto kernel scope host src 5.9.243.187
    local 169.254.1.1 dev lo proto kernel scope host src 169.254.1.1
    ```

### tproxy DNS nameserver

_Please use the preferred tunneller if possible. It is not necessary to manually configure DNS for the preferred tunneller_

`ziti-tunnel tproxy` mode runs a built-in nameserver serving on udp://127.0.0.1:53 by default, and configurable with a command-line option. The nameserver is authoritative for all authorized OpenZiti Services' domain names. This nameserver must be primary in the host's resolver
configuration. A self-test is performed when ziti-tunnel starts to ensure that OpenZiti domains names are resolvable:

```log
INFO[0002] dns server started on 127.0.0.1:53           
INFO[0002] adding ziti-tunnel.resolver.test -> 19.65.28.94 to resolver 
INFO[0002] removing ziti-tunnel.resolver.test from resolver 
```

The test involves inserting a known hostname/IP address into the internal DNS server, and using the system
resolver to retrieve the address of the hostname. _ziti-tunnel will exit if the DNS self-test fails._

Linux distributions typically manage the contents of /etc/resolv.conf, so simply editing the file
will only work for a short time until /etc/resolv.conf is overwritten by the managing process.

Resolver configuration changes must survive restarts of the Linux name resolution manager. Linux
distrubutions use one of several name resolution managers. The simplest way to determine which name
resolution manager is being used by your Linux distrubtion is to look at /etc/resolv.conf:

```bash
ls -l /etc/resolv.conf
```

* If /etc/resolv.conf is a regular file, then it is most likely being managed by `dhclient`.
* If /etc/resolv.conf is a symlink to a file in /run/systemd/resolve, then it is being
  managed by `systemd-resolved`
* If /etc/resolv.conf is a symlink at all it is being managed by some process on which the particular steps to configure the primary nameserver will depend.

### dhclient

_Please use the preferred tunneller if possible. It is not necessary to manually configure DNS for the preferred tunneller_

If your Linux distribution uses dhclient, you can configure the system resolver to use
ziti-tunnel's internal DNS server first by adding the following to /etc/dhcp/dhclient.conf:

```conf
prepend domain-name-servers 127.0.0.1;
```

Then restart network manager. Unless you know the name of the NetworkManager systemd
service on your Linux distrubtion, it's probably easiest to reboot the host.

### systemd-resolved

_Please use the preferred tunneller if possible. It is not necessary to manually configure DNS for the preferred tunneller_

```bash
sudo ln -sf /run/systemd/resolve/resolv.conf /etc
echo -e "[Resolve]\nDNS=127.0.0.1" | sudo tee /etc/systemd/resolved.conf.d/ziti-tunnel.conf
sudo systemctl restart systemd-resolved
```

If you are unable to control the resolver on your operating system, ziti-tunnel can use/update a hosts file for
any hostnames that it tunnels:

```bash
ziti-tunnel run --resolver file:///etc/hosts "${HOME}/ziti.json"
```

### IP Address Assignment

If the service specifies a hostname for its address, ziti-tunnel resolves the hostname and adds the result to its
internal DNS server:

```log
[0127]  INFO adding myservice.mydomain.com -> 45.60.32.165 to resolver
```

If the service hostname does not resolve, ziti-tunnel will find an unused link-local address and assign it to
the route for the service:

```log
[0012]  INFO adding bogushost.net -> 169.254.1.4 to resolver
[0012]  INFO ziti/tunnel/protocols/tcp.Listen: Accepting on 169.254.1.4:25 service=telnet
```

### Troubleshooting

* The simplest step you can take toward a diagnosis is to reduce the minimum message log level. This usually means lower-level DEBUG messages and above are emitted in addition to the default level of INFO level and above e.g. WARN, ERROR, etc.

  For `ziti-edge-tunnel`: DEBUG log level is `ziti-edge-tunnel --verbose=4`

  For the alternative tunnellers: DEBUG log level is like `ziti-tunnel --verbose`

* If you change your package repo subscription or install the same DEB or RPM package from another source, excluding normal upgrades and downgrades, then it may be necessary to reload the systemd service unit definitions:

  ```bash
  sudo systemctl daemon-reload
  ```

* You may inspect the loaded identities' info for a running `ziti-edge-tunnel` by dumping it to stdout or the systemd journal with an IPC command, or you may signal to dump the identities' info to a file.

  ```bash
  # dump indentities info to std our journal if systemd unit with IPC command
  ./ziti-edge-tunnel dump
  ```

  ```bash
  # dump identities info to a file and inspect
  sudo pkill -USR1 -f ziti-edge-tunnel
  less /tmp/ziti-dump.964315.dump
  ```

* If the tunneller is crashing then it may be crucial to collect and analyze the core dump file. You may need to enable saving core dumps depending upon your OS configuration. 

  You can see how dump files are handled by inspecting this file, which is from Ubuntu 20.10.

  ```bash
  $ cat /proc/sys/kernel/core_pattern
  |/usr/share/apport/apport %p %s %c %d %P %E
  ```

  In this case the dump is handled by `apport` which saves the file in `/var/crash`. I'll need to follow the `apport` documentation to learn how to unpack and parse the dump file.
