# Simple PKI
`spki` is a bash script wrapper for [OpenSSL](https://github.com/openssl/openssl) that generates and manages a simple PKI suitable for small deployments. It supports both CRL's and OCSP.

The wrapper is based on Jamie Nguyen's guide: [OpenSSL Certificate Authority](https://jamielinux.com/docs/openssl-certificate-authority/ )
## Installation
Copy `spki` to a location in your path.

## Configuration
The top of the script contains several configuration variables; the defaults correspond to the guide.

`ROOT_DIR` - The base directory where all PKI files are stored

`ROOT_PREFIX` - Prefix for all Root CA files

`INTRMDT_PREFIX` - Prefix for all Intermediate CA files

`CLIENT_ENCRYPTION` - Default encryption for client keys

### Certificate Revocation List (CRL)
CRL's are automatically generated during initialization if either or both of the DP variables are set. The Intermedate CA Certificate will use the Root CRL DP; all other generated certificates use the Intermediate CRL DP. CRL's are automatically updated on revocation. CRL's served over http should **not** use https. Since the CRL files are frequently regenerated, it is recommended to serve the file directly from the spki root folder, for example by using a soft link. Furthermore, the CRL's are checked during initialization and certificate creation, so it is recommended to prepare the server in advance.

`ROOT_CRL_DP` - CRL Distribution Point for the Root CA (e.g. 'URI:http://domain.com/my.crl,URI:http://backup.domain.com/my.crl')

`INTRMDT_CRL_DP` - CRL Distribution Point for the Intermediate CA (e.g. 'URI:http://domain.com/my.crl,URI:http://backup.domain.com/my.crl')

### Online Certificate Status Protocol (OCSP)
OCSP signing keys are automatically generated during initialization if either or both of the OCSP variables are set.

`ROOT_OCSP` - Root CA OCSP Server (e.g. 'URI:http://ocsp.domain.com')


`INTRMDT_OCSP`- Intermediate CA OCSP (e.g. 'URI:http://ocsp.domain.com')

## Usage
* `spki init` - Initialize the PKI. This process first sets up the default Subject fields in the OpenSSL configuration files, then generates the Root CA, Intermediate CA, and a combined CA chain file. CRL's and OCSP certificates are also generated
* `spki create (server | user) <file-prefix>` - Create and sign a key pair with the Intermediate CA. `server` or `user` specifies particular extensions to use. These can be modified by changing the configuration files after initialization. The `file-prefix` is prepended to various file extensions (`.key.pem`, `.cert.pem`, `.csr.pem`)
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

* `spki create-intermediate` - Recreate the Intermediate CA key and certificate. This command also regenerates the Intermediate CRL if necessary
* `spki sign (server | user) <CSR> <certificate>` - Sign a specified `CSR` file with the `server` or `user` extensions (see above). `certificate` specifies the output file
* `spki list` - List all of the certificates signed by the Intermediate CA, including expiration times and revocation times
* `spki verify (certificate | file-prefix)` - Dump the certificate information and verify the chain of trust using the Root CA->Intermediate CA chain. Can be specified as a file or as the prefix used in `spki create`
* `spki export-pkcs12 <file-prefix>` - Export the key, certificate, and CA chain file to pkcs12 format
* `spki revoke (certificate | file-prefix) [reason]` - Revoke the specified certificate. `reason` can be one of: `unspecified`, `keyCompromise`, `CACompromise`, `affiliationChanged`, `superseded`, `cessationOfOperation`, `certificateHold`. This command automatically regenerates the Intermediate CRL
* `spki revoke-intermediate [reason]` - Revoke the Intermediate CA certificate. `reason` can be one of the options above. This command automatically regenerates the Root CRL
* `spki list-crl` - Dump information about the CRL's and the revoked certificates
* `spki generate-crl [-rootca]` - Generate the Intermediate CRL file. This should be run regularly. Pass `-rootca` to generate the Root CRL file
* `spki generate-ocsp [-rootca]` - Generate the Intermediate OCSP signing pair. Pass `-rootca` to generate the Root OCSP signing pair
* `spki ocsp-responder <port> [-rootca]` - Start an OCSP responder on the specified port using `openssl ocsp`. The command by default uses the Intermediate CA database, but can be changed to the Root CA database by passing `-rootca`. This can be turned into a service by using `systemd`, for example. The OpenSSL OCSP responder may not be suitable for high traffic.
* `spki ocsp-query <url> (certificate | file-prefix) [-rootca]` - Send an OCSP query for the specified certificate to the specified url (e.g. `http://127.0.0.1:12345`. The command uses the full chain file by default, suitable for verifying certificates signed by the Intermediate CA. Specify `-rootca` to use just the Root CA, suitable for verifying the Intermediate CA certificate.


## Examples
