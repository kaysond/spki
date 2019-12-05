# Simple PKI
`spki` is a bash script wrapper for [OpenSSL](https://github.com/openssl/openssl) that generates and manages a simple PKI suitable for small deployments. It supports both CRL's and OCSP.

The wrapper is based on Jamie Nguyen's guide: [OpenSSL Certificate Authority](https://jamielinux.com/docs/openssl-certificate-authority/ )
## Installation
Copy the latest release of `spki` to a location in your path. [Releases](https://github.com/kaysond/spki/releases) use [semantic versioning](https://semver.org/) to identify backwards-incompatible changes.

## Configuration
The top of the script contains several configuration variables; the defaults correspond to the guide. External configuration methods that do not require script modification are also supported (see below).

`ROOT_DIR` - The base directory where all PKI files are stored

`ROOT_PREFIX` - Prefix for all Root CA files

`INTRMDT_PREFIX` - Prefix for all Intermediate CA files

### Certificate Revocation List (CRL)
CRL's are automatically generated during initialization if either or both of the DP variables are set. The Intermedate CA Certificate will use the Root CRL DP; all other generated certificates use the Intermediate CRL DP. CRL's are automatically updated on revocation. CRL's served over http should **not** use https. Since the CRL files are frequently regenerated, it is recommended to serve the file directly from the spki root folder, for example by using a soft link. Furthermore, the CRL's are checked during initialization and certificate creation, so it is recommended to prepare the server in advance.

`ROOT_CRL_DP` - CRL Distribution Point for the Root CA (e.g. 'URI:http://domain.com/my.crl,URI:http://backup.domain.com/my.crl')

`INTRMDT_CRL_DP` - CRL Distribution Point for the Intermediate CA (e.g. 'URI:http://domain.com/my.crl,URI:http://backup.domain.com/my.crl')

### Online Certificate Status Protocol (OCSP)
OCSP signing keys are automatically generated during initialization if either or both of the OCSP variables are set.

`ROOT_OCSP` - Root CA OCSP Server (e.g. 'URI:http://ocsp.domain.com')

`INTRMDT_OCSP`- Intermediate CA OCSP (e.g. 'URI:http://ocsp.domain.com')

### OpenSSL DN Defaults
`spki init` prompts for the default values for certificate Distinguished Name parts and stores them in the OpenSSL configuration file. These can also be specified programmatically by using the following variables:

* `countryName`
* `stateOrProvinceName`
* `localityName`
* `organizationalUnitName`
* `organizationName`
* `emailAddress`

(or set them to '.' to prevent prompting that field)

### External Configuration
Configuration can be specified externally, without modifying the script, via environment variables. The precedence order of the configuration methods is:
1. Configuration File
2. Environment Variables
3. In-script Variables

#### Configuration File
The configuration file can be specified in the environment variable `SPKI_CONFIG_FILE`. This file is loaded directly by bash and should contain a list of local variable definitions such as
```
ROOT_DIR=/root/ca
ROOT_PREFIX=root
countryName=US
```

Note: If this file is loaded, all other environment variables are ignored.

#### Environment Variables
Variables defined in the script itself can be overriden by environment variables. The environment variable name should be those in the script but prefixed with `SPKI_` (e.g. `SPKI_ROOT_DIR` and `SPKI_ROOT_CRL_DP`).

## Usage
* `spki init` - Initialize the PKI. This process first sets up the default Subject fields in the OpenSSL configuration files, then generates the Root CA, Intermediate CA, and a combined CA chain file. CRL's and OCSP certificates are also generated
* `spki create (server | user | client_server) <file-prefix>` - Create and sign a key pair with the Intermediate CA. `server`, `user` or `client_server` specifies particular extensions to use. These can be modified by changing the configuration files after initialization. The `file-prefix` is prepended to various file extensions (`.key.pem`, `.cert.pem`, `.csr.pem`)
  * `server`
    * `nsCertType = server`
    * `authorityKeyIdentifier = keyid,issuer:always`
    * `keyUsage = critical, digitalSignature, keyEncipherment`
    * `extendedKeyUsage = serverAuth`
 
  * `user`
    * `nsCertType = client, email`
    * `authorityKeyIdentifier = keyid,issuer`
    * `keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment`
    * `extendedKeyUsage = clientAuth, emailProtection`  
  
  * `client_server`
    * `nsCertType = client, server`
    * `authorityKeyIdentifier = keyid,issuer`
    * `keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment`
    * `extendedKeyUsage = clientAuth, serverAuth`

* `spki create-intermediate` - Recreate the Intermediate CA key and certificate. This command also regenerates the Intermediate CRL if necessary
* `spki sign (server | user | client_server) <CSR> <certificate>` - Sign a specified `CSR` file with the `server`, `user` or `client_server` extensions (see above). `certificate` specifies the output file
* `spki list` - List all of the certificates signed by the Intermediate CA, including expiration times and revocation times
* `spki verify (certificate | file-prefix)` - Dump the certificate information and verify the chain of trust using the Root CA->Intermediate CA chain. Can be specified as a file or as the prefix used in `spki create`
* `spki export-pkcs12 <file-prefix>` - Export the key, certificate, and CA chain file to pkcs12 format
* `spki export-truststore <file-prefix>` - Export CA chain file to pkcs12 format compatible with java expectations. Requires keytool (bundled with java)
* `spki revoke (certificate | file-prefix) [reason]` - Revoke the specified certificate. `reason` can be one of: `unspecified`, `keyCompromise`, `CACompromise`, `affiliationChanged`, `superseded`, `cessationOfOperation`, `certificateHold`. This command automatically regenerates the Intermediate CRL
* `spki revoke-intermediate [reason]` - Revoke the Intermediate CA certificate. `reason` can be one of the options above. This command automatically regenerates the Root CRL
* `spki list-crl` - Dump information about the CRL's and the revoked certificates
* `spki generate-crl [-rootca]` - Generate the Intermediate CRL file. This should be run regularly. Pass `-rootca` to generate the Root CRL file
* `spki generate-ocsp [-rootca]` - Generate the Intermediate OCSP signing pair. Pass `-rootca` to generate the Root OCSP signing pair
* `spki ocsp-responder <port> [-rootca]` - Start an OCSP responder on the specified port using `openssl ocsp`. The command by default uses the Intermediate CA database, but can be changed to the Root CA database by passing `-rootca`. This can be turned into a service by using `systemd`, for example, but the OpenSSL OCSP responder may not be suitable for high traffic.
* `spki ocsp-query <url> (certificate | file-prefix) [-rootca]` - Send an OCSP query for the specified certificate to the specified url (e.g. http://127.0.0.1:12345). The command uses the full chain file by default, suitable for verifying certificates signed by the Intermediate CA. Specify `-rootca` to use just the Root CA, suitable for verifying the Intermediate CA certificate.
* `spki update-config` - Regenerate the openssl configuration files. This allows the configuration variables, such as CRL or OCSP to be updated. It re-prompts for the certificate defaults.

## Automating `spki init`

You can automate the PKI initialization by doing the following.

Prepare a configuration file named `config`, making sure to specify default DN parts (`countryName`, `stateOrProvinceName`, `localityName`, etc.) i.e.:
```
ROOT_DIR=/tmp/spki/
countryName=PL
stateOrProvinceName=Warsaw
localityName=Warsaw
organizationalUnitName=Developers
organizationName=Company Ltd
emailAddress=mail@company.com
```

Then use following script to create the PKI and a certificate in one go:
```bash
SPKI_CONFIG_FILE=$(pwd)/config
export SPKI_CONFIG_FILE

source $SPKI_CONFIG_FILE

ROOT_PRIVATE_KEY_PASSWORD="<INSERT PASSWORD HERE>"
ROOT_COMMON_NAME="Root CA"
ROOT_COUNTRY_NAME="$countryName"
ROOT_PROVINCE_NAME="$stateOrProvinceName"
ROOT_LOCALITY_NAME="$localityName"
ROOT_ORGANIZATION_NAME="$organizationName"
ROOT_ORGANIZATIONAL_UNIT_NAME="$organizationalUnitName"
ROOT_MAIL="$emailAddress"

INTERMEDIATE_COMMON_NAME="Intermediate CA"
INTERMEDIATE_COUNTRY_NAME="$countryName"
INTERMEDIATE_PROVINCE_NAME="$stateOrProvinceName"
INTERMEDIATE_LOCALITY_NAME="$localityName"
INTERMEDIATE_ORGANIZATION_NAME="$organizationName"
INTERMEDIATE_ORGANIZATIONAL_UNIT_NAME="$organizationalUnitName"
INTERMEDIATE_MAIL="$emailAddress"

INTERMEDIATE_PRIVATE_KEY_PASSWORD="<INSERT PASSWORD HERE>"

ANYKEY="k"
YES="y"

./spki init <<EOF
$ROOT_PRIVATE_KEY_PASSWORD
$ROOT_PRIVATE_KEY_PASSWORD
$ROOT_COMMON_NAME
$ROOT_COUNTRY_NAME
$ROOT_PROVINCE_NAME
$ROOT_LOCALITY_NAME
$ROOT_ORGANIZATION_NAME
$ROOT_ORGANIZATIONAL_UNIT_NAME
$ROOT_MAIL
$ANYKEY$INTERMEDIATE_PRIVATE_KEY_PASSWORD
$INTERMEDIATE_PRIVATE_KEY_PASSWORD
$INTERMEDIATE_COMMON_NAME
$INTERMEDIATE_COUNTRY_NAME
$INTERMEDIATE_PROVINCE_NAME
$INTERMEDIATE_LOCALITY_NAME
$INTERMEDIATE_ORGANIZATION_NAME
$INTERMEDIATE_ORGANIZATIONAL_UNIT_NAME
$INTERMEDIATE_MAIL
$YES
$YES
$ANYKEY
EOF

CERT_PRIVATE_KEY_PASSWORD="<INSERT PASSWORD HERE>"
CERT_COMMON_NAME="Test client_server"
./spki create client_server test <<EOF
$CERT_PRIVATE_KEY_PASSWORD
$CERT_PRIVATE_KEY_PASSWORD
$CERT_COMMON_NAME
$ROOT_COUNTRY_NAME
$ROOT_PROVINCE_NAME
$ROOT_LOCALITY_NAME
$ROOT_ORGANIZATION_NAME
$ROOT_ORGANIZATIONAL_UNIT_NAME
$ROOT_MAIL
$INTERMEDIATE_PRIVATE_KEY_PASSWORD
$YES
$YES
$ANYKEY
EOF
```

## Examples
* [`spki init`](https://asciinema.org/a/238438)

* [`spki create, spki revoke`](https://asciinema.org/a/238544)

* [`spki ocsp-responder, spki ocsp-query`](https://asciinema.org/a/238767)

## Contributing
See [CONTRIBUTING.md](CONTRIBUTING.md)