## PKI Troubleshooting

Configuring a Ziti Network's PKI can be confusing. Validating a single side of a mutual TLS connection is
straightforward it becomes tedious to ensure all the certificates and cas in use are valid when you have a fully
configured Ziti Network.  It's the goal of this page to make diagnosing PKI issues eaiser. This guide will also use the
paths you will find in the Ziti Edge - Developer Edition. Change paths accordingly.

### Prerequisites

The following steps are [bash-based](https://en.wikipedia.org/wiki/Bash_(Unix_shell)) functions and use the
[openssl](https://www.openssl.org/), [jq](https://stedolan.github.io/jq/) and [ruby](https://www.ruby-lang.org/en/)
commands. If you don't have bash, openssl and ruby - this page is not for you! Do your best to follow along with the
scripts and guidance herein or just make sure bash, openssl, ruby, and jq are installed. All of which are widely 
available on linux/MacOS/Windows.

The `ruby` and `jq` commands are not strictly required. They are used to make it easy for you to copy/paste these
commands. The `ruby` command is used to translate yaml into json while the `jq` command is used to pull the specific
values out of the given files. You can certainly do the same manually (without `ruby` and `jq`) if you choose.

#### Define the verifyCertAgainstPool Function

In your bash prompt copy and paste these two functions:

    function yaml2json()
    {
        ruby -ryaml -rjson -e 'puts JSON.pretty_generate(YAML.load(ARGF))' $*
    }

    function verifyCertAgainstPool()
    {
        if [[ "" == "$1" ]]
        then
            echo "Usage: verifyCertAgainstPool [cert to test] [ca pool to use]"
            return 1
        fi
        
        if [[ "" == "$2" ]]
        then
            echo "Usage: verifyCertAgainstPool [cert to test] [ca pool to use]"
            return 1
        fi

        echo "    Verifying that this certificate:"
        echo "        - $1"
        echo "    is valid for this ca pool:"
        echo "        - $2"
        echo ""
        openssl verify -partial_chain -CAfile "$2" "$1"
        if [ $? -eq 0 ]; then
            echo ""
            echo "============      SUCCESS!      ============"
        else
            echo ""
            echo "============ FAILED TO VALIDATE ============"
        fi
    }

### Validating the PKI

Every connection in a Ziti Network is mutally authenticated via X509 certificates. It is easiest to first identify the
two components trying to communicate to isolate and minimize the configuration and files that need to be inspected.
Below you will find sections relevant to each of the pieces of Ziti which connect.

Each section will refer to a bash variable that is expected to be established before running the command. This variable
is intended to make it easier for you to simply copy/paste the command and determine if the configuration is valid or
not.

Using the provided bash function above - you will see one of two results:

#### Success

    verifyCertAgainstPool /path/to/cert-to-test.cert /path/to/capool.pem
        Verifying that this certificate:
            - /path/to/cert-to-test.cert
        is valid for this ca pool:
            - /path/to/capool.pem

    /path/to/cert-to-test.cert: OK

    ============      SUCCESS!      ============

#### Failure

    verifyCertAgainstPool /path/to/cert-to-test.cert /path/to/capool.pem
        Verifying that this certificate:
            - /path/to/cert-to-test.cert
        is valid for this ca pool:
            - /path/to/capool.pem

    C = US, ST = NC, L = Charlotte, O = NetFoundry, OU = Ziti, CN = 87f8cee9-b288-49f1-ab90-b664af29e17a
    error 20 at 0 depth lookup: unable to get local issuer certificate
    error /path/to/cert-to-test.cert: verification failed

    ============ FAILED TO VALIDATE ============

--------------------------------------------------------------

### Ziti Edge Router to Controller

#### Variables to Establish Manually

These two variables represent the Ziti Edge Router configuration file and the Controller configuration file.

    controller_config_file=~/.config/ziti/ziti-controller/ziti_controller.yml
    edge_router_config_file=~/.config/ziti/ziti-router/ziti_router.yml

#### Variables - Copy/Paste

These commands extract the files specified in the configuration and store them into the assigned variables.

    edge_router_cert=$(yaml2json $edge_router_config_file | jq -j .identity.cert)
    signing_cert=$(yaml2json $controller_config_file | jq -j .edge.enrollment.signingCert.cert)
    controller_cert=$(yaml2json $controller_config_file | jq -j .identity.cert)
    edge_router_ca=$(yaml2json $edge_router_config_file | jq -j .identity.ca)

#### Commands to Verify PKI Configuration

Both of these commands should report SUCCESS.

    verifyCertAgainstPool $edge_router_cert $signing_cert
    verifyCertAgainstPool $controller_cert $edge_router_ca

--------------------------------------------------------------

### Ziti Client to Controller - API

#### Variables to Establish Manually

These two variables represent the identity file in json for a Ziti client and the Controller configuration file.

    identity_file=/path/to/enrolled-identity.json
    controller_config_file=~/.config/ziti/ziti-controller/ziti_controller.yml

#### Variables - Copy/Paste

These commands will extract the cert and ca from the enrolled identity file and put it into a file in the /tmp folder

    jq -j .id.cert $identity_file | cut -d ":" -f2 > /tmp/identity.cert
    jq -j .id.ca $identity_file | cut -d ":" -f2 > /tmp/identity.ca

These commands extract the files specified in the configuration and store them into the assigned variables.

    controller_cert=$(yaml2json $controller_config_file | jq -j .identity.cert)
    signing_cert=$(yaml2json $controller_config_file | jq -j .edge.enrollment.signingCert.cert)
    
    controller_api_server_cert=$(yaml2json $controller_config_file | jq -j .edge.api.identity.server_cert)
    if [[ "null" == "$controller_api_server_cert" ]]; then controller_api_server_cert=$(yaml2json $controller_config_file | jq -j .identity.server_cert); fi

#### Commands to Verify PKI Configuration

Both of these commands should report SUCCESS.

    verifyCertAgainstPool /tmp/identity.cert $signing_cert
    verifyCertAgainstPool $controller_api_server_cert /tmp/identity.ca

--------------------------------------------------------------

### Ziti Client to Ziti Edge Router - Data

#### Variables to Establish Manually

These two variables represent the identity file in json for a Ziti client and the Controller configuration file.

    identity_file=/path/to/enrolled-identity.json
    edge_router_config_file=~/.config/ziti/ziti-router/ziti_router.yml

#### Variables - Copy/Paste

This command will extract the ca from the enrolled identity file and put it into a file in the /tmp folder

    jq -j .id.ca $identity_file | cut -d ":" -f2 > /tmp/identity.ca

This command extracts the file specified in the configuration and stores it into the assigned variable.

    edge_router_cert=$(yaml2json $edge_router_config_file | jq -j .identity.cert)

#### Commands to Verify PKI Configuration

The following command should report SUCCESS.

    verifyCertAgainstPool $edge_router_cert /tmp/identity.ca
