# Tunnelers

[!include[](/ziti/clients/tunneler-overview.md)]

Each tunneller operates similarly. The goal is to have the tunneler intercecpt traffic destined for Ziti
services and forward that traffic over the Ziti overlay instead of the underlay network.  There are two basic modes a
tunneler operate in: seamless and proxy. A seamless tunneler will transparently intercept traffic via IPv4 address or
DNS whereas a tunneler in proxy mode works as a proxy. Seamless mode is transparent to existing services and
applications. Proxy mode is not transparent at all. It requires applications to send traffic to the localhost proxy
specifically. This means when running in proxy mode it does not do any intercepting at all.

The OpenZiti project provides tunnellers for each major operating system.

[!include[](linux.md)]

[!include[](windows.md)]

[!include[](android.md)]

[!include[](iOS.md)]

[!include[](macos.md)]
