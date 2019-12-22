# Some tests require http-server
# npm install http-server -g

### RREPLACE LITERALS WITH VARIABLES WHERE PSBLE
load test_helpers

setup() {
	load_vars
	export SPKI_ROOT_DIR="/tmp/spki"
}

teardown() {
	cleanup
}

@test "invoking spki without arguments prints usage" {
  run ./spki
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "Usage:" ]
}

@test "init creates a root and intermediate cert with the right DNs" {
	#skip
	run init_from_input

	ROOTCERT=$(openssl x509 -in /tmp/spki/certs/ca.cert.pem -noout -text)
	echo "$ROOTCERT" | grep "Issuer: CN = Root CA, C = PL, ST = Warsaw, L = Warsaw, O = Company Ltd, OU = Developers, emailAddress = mail@company.com"
	echo "$ROOTCERT" | grep "Subject: CN = Root CA, C = PL, ST = Warsaw, L = Warsaw, O = Company Ltd, OU = Developers, emailAddress = mail@company.com"
	INTRMDTCERT=$(openssl x509 -in /tmp/spki/intermediate/certs/intermediate.cert.pem -noout -text)
	echo "$INTRMDTCERT" | grep "Issuer: CN = Root CA, C = PL, ST = Warsaw, L = Warsaw, O = Company Ltd, OU = Developers, emailAddress = mail@company.com"
	echo "$INTRMDTCERT" | grep "Subject: CN = $INTERMEDIATE_COMMON_NAME, C = PL, ST = Warsaw, L = Warsaw, O = Company Ltd, OU = Developers, emailAddress = mail@company.com"
}

@test "init with config file overwrites file and env vars" {
	#skip
	export SPKI_CONFIG_FILE="test/config"
	export SPKI_ROOT_PREFIX="test"
	run init_from_input

	[ "$status" -eq 0 ]
	[ -f  /tmp/spki/certs/ca_filetest.cert.pem ]
	[ -f  /tmp/spki/private/ca_filetest.key.pem ]
	[ -f /tmp/spki/intermediate/certs/intermediate_filetest.cert.pem ]
	[ -f /tmp/spki/intermediate/private/intermediate_filetest.key.pem ]
}

@test "conf defaults get set properly from user input" {
	#skip
	run init_from_input

	[ "$status" -eq 0 ]

	read -d '' CONF_DEFS <<-EOF || true
		commonName = Common Name
		countryName = Country Name (2 letter code)
		countryName_default = PL
		stateOrProvinceName = State or Province Name
		stateOrProvinceName_default = Warsaw
		localityName = Locality Name
		localityName_default = Warsaw
		0.organizationName = Organization Name 0
		0.organizationName_default = Company Ltd
		organizationalUnitName = Organizational Unit Name
		organizationalUnitName_default = Developers
		emailAddress = Email Address
		emailAddress_default = mail@company.com
		EOF

	# These tests check that all lines of $CONF_DEFS exist in openssl.cnfs
	! diff /tmp/spki/openssl.cnf <(echo "$CONF_DEFS") | grep -E "^>"
	! diff /tmp/spki/intermediate/openssl.cnf <(echo "$CONF_DEFS") | grep -E "^>"
}

@test "conf defaults get set properly from env vars" {
	#skip
	export SPKI_countryName=US
	export SPKI_stateOrProvinceName=CA
	export SPKI_localityName=SoCal
	export SPKI_organizationalUnitName=Testers
	export SPKI_organizationName=Company\ Ltd\ Inc
	export SPKI_emailAddress=mail@companyltdinc.com
	#Intermediate DN must match Root
	INTERMEDIATE_COUNTRY_NAME="$SPKI_countryName"
	INTERMEDIATE_PROVINCE_NAME="$SPKI_stateOrProvinceName"
	INTERMEDIATE_LOCALITY_NAME="$SPKI_localityName"
	INTERMEDIATE_ORGANIZATION_NAME="$SPKI_organizationName"
	INTERMEDIATE_ORGANIZATIONAL_UNIT_NAME="$SPKI_organizationalUnitName"
	INTERMEDIATE_MAIL="$SPKI_emailAddress"

	run init_from_envvars

	[ "$status" -eq 0 ]
	read -d '' CONF_DEFS <<-EOF || true
		commonName = Common Name
		countryName = Country Name (2 letter code)
		countryName_default = US
		stateOrProvinceName = State or Province Name
		stateOrProvinceName_default = CA
		localityName = Locality Name
		localityName_default = SoCal
		0.organizationName = Organization Name 0
		0.organizationName_default = Company Ltd Inc
		organizationalUnitName = Organizational Unit Name
		organizationalUnitName_default = Testers
		emailAddress = Email Address
		emailAddress_default = mail@companyltdinc.com
	EOF

	# These tests check that all lines of $CONF_DEFS exist in openssl.cnfs
	! diff /tmp/spki/openssl.cnf <(echo "$CONF_DEFS") | grep -E "^>"
	! diff /tmp/spki/intermediate/openssl.cnf <(echo "$CONF_DEFS") | grep -E "^>"
}

@test "create server certificate" {
	#skip
	init_from_input

	run create server test
	[ "$status" -eq 0 ]
	[ -f "/tmp/spki/intermediate/private/test.key.pem" ]
	[ -f "/tmp/spki/intermediate/certs/test.cert.pem" ]

	# Check for correct DNs
	CERT=$(openssl x509 -in /tmp/spki/intermediate/certs/test.cert.pem -noout -text)
	echo "$CERT" | grep "Issuer: CN = $INTERMEDIATE_COMMON_NAME, C = PL, ST = Warsaw, L = Warsaw, O = Company Ltd, OU = Developers, emailAddress = mail@company.com"
	echo "$CERT" | grep "Subject: CN = Test Cert, C = PL, ST = Warsaw, L = Warsaw, O = Company Ltd, OU = Developers, emailAddress = mail@company.com"

	# Check for correct extensions
	read -d '' EXTENSIONS <<-EOF || true
		Netscape Cert Type:
		SSL Server
		X509v3 Key Usage: critical
		Digital Signature, Key Encipherment
		X509v3 Extended Key Usage:
		TLS Web Server Authentication
	EOF

	! diff -Z <(echo "$CERT" | sed 's/^[ \t]*//') <(echo "$EXTENSIONS") | grep -E "^>"
}

@test "create user certificate" {
	#skip
	init_from_input

	run create user test
	[ "$status" -eq 0 ]
	[ -f "/tmp/spki/intermediate/private/test.key.pem" ]
	[ -f "/tmp/spki/intermediate/certs/test.cert.pem" ]

	# Check for correct DNs
	CERT=$(openssl x509 -in /tmp/spki/intermediate/certs/test.cert.pem -noout -text)
	echo "$CERT" | grep "Issuer: CN = $INTERMEDIATE_COMMON_NAME, C = PL, ST = Warsaw, L = Warsaw, O = Company Ltd, OU = Developers, emailAddress = mail@company.com"
	echo "$CERT" | grep "Subject: CN = Test Cert, C = PL, ST = Warsaw, L = Warsaw, O = Company Ltd, OU = Developers, emailAddress = mail@company.com"

	# Check for correct extensions
	read -d '' EXTENSIONS <<-EOF || true
		Netscape Cert Type:
		SSL Client, S/MIME
		X509v3 Key Usage: critical
		Digital Signature, Non Repudiation, Key Encipherment
		X509v3 Extended Key Usage:
		TLS Web Client Authentication, E-mail Protection
	EOF

	! diff -Z <(echo "$CERT" | sed 's/^[ \t]*//') <(echo "$EXTENSIONS") | grep -E "^>"
}

@test "create client_server certificate" {
	#skip
	init_from_input

	run create client_server test
	[ "$status" -eq 0 ]
	[ -f "/tmp/spki/intermediate/private/test.key.pem" ]
	[ -f "/tmp/spki/intermediate/certs/test.cert.pem" ]

	# Check for correct DNs
	CERT=$(openssl x509 -in /tmp/spki/intermediate/certs/test.cert.pem -noout -text)
	echo "$CERT" | grep "Issuer: CN = $INTERMEDIATE_COMMON_NAME, C = PL, ST = Warsaw, L = Warsaw, O = Company Ltd, OU = Developers, emailAddress = mail@company.com"
	echo "$CERT" | grep "Subject: CN = Test Cert, C = PL, ST = Warsaw, L = Warsaw, O = Company Ltd, OU = Developers, emailAddress = mail@company.com"

	# Check for correct extensions
	read -d '' EXTENSIONS <<-EOF || true
		Netscape Cert Type:
		SSL Client, SSL Server
		X509v3 Key Usage: critical
		Digital Signature, Non Repudiation, Key Encipherment
		X509v3 Extended Key Usage:
		TLS Web Client Authentication, TLS Web Server Authentication
	EOF
	! diff -Z <(echo "$CERT" | sed 's/^[ \t]*//') <(echo "$EXTENSIONS") | grep -E "^>"
}

@test "verify" {
	#skip
	init_from_input
	run create client_server test

	run echo "$ANYKEY" | ./spki verify test
	[ "$status" -eq 0 ] # by prefix

	run echo "$ANYKEY" | ./spki verify "/tmp/spki/intermediate/certs/test.cert.pem"
	[ "$status" -eq 0 ] # by filename
}

@test "sign" {
	#skip
	init_from_input
	create_csr

	CERT="/tmp/spki/intermediate/certs/test.cert.pem"
	run sign client_server "$CSR" "$CERT"

	[ "$status" -eq 0 ]
	[ -f "/tmp/spki/intermediate/certs/test.cert.pem" ]
}

@test "export to pkcs12" {
	#skip
	init_from_input
	create client_server test

	run pkcs12 test
	[ "$status" -eq 0 ]
	[ -f "/tmp/spki/intermediate/certs/test.p12" ]
}

@test "list" {
	#skip
	init_from_input
	create client_server test

	run ./spki list
	[ "$status" -eq 0 ]
	# Bash test + regex avoids whitespace issues
	[[ "${lines[0]}" =~ "/CN=$CERT_COMMON_NAME/C=$countryName/ST=$stateOrProvinceName/L=$localityName/O=$organizationName/OU=$organizationalUnitName/emailAddress=$emailAddress" ]]
	[[ "${lines[1]}" =~ "Status: Valid" ]]
	[[ "${lines[3]}" =~ "Serial: 1000" ]]
}

@test "generate crl" {
	#skip
	run init_from_input_crl
	[ "$status" -eq 0 ]
	[ -f "/tmp/spki/crl/ca.crl.der" ]
	[ -f "/tmp/spki/intermediate/crl/intermediate.crl.der" ]

	run ./spki generate-crl <<-EOF
	$INTERMEDIATE_PRIVATE_KEY_PASSWORD

	$ANYKEY
	EOF
	[ "$status" -eq 0 ]

	run ./spki generate-crl -rootca <<-EOF
	$ROOT_PRIVATE_KEY_PASSWORD

	$ANYKEY
	EOF
	[ "$status" -eq 0 ]
}

@test "list-crl" {
	#skip
	init_from_input_crl
	run ./spki list-crl
	[ "$status" -eq 0 ]
	[[ "${lines[1]}" =~ "Certificate Revocation List (CRL):" ]]
	[[ "${lines[2]}" =~ "Version 2 (0x1)" ]]
	[[ "${lines[3]}" =~ "Signature Algorithm: sha256WithRSAEncryption" ]]
	[[ "${lines[4]}" =~ "Issuer: CN = $ROOT_COMMON_NAME, C = PL, ST = Warsaw, L = Warsaw, O = Company Ltd, OU = Developers, emailAddress = mail@company.com" ]]

	[[ "${lines[16]}" =~ "Certificate Revocation List (CRL):" ]]
	[[ "${lines[17]}" =~ "Version 2 (0x1)" ]]
	[[ "${lines[18]}" =~ "Signature Algorithm: sha256WithRSAEncryption" ]]
	[[ "${lines[19]}" =~ "Issuer: CN = $INTERMEDIATE_COMMON_NAME, C = PL, ST = Warsaw, L = Warsaw, O = Company Ltd, OU = Developers, emailAddress = mail@company.com" ]]
}

@test "create and revoke cert" {
	init_from_input_crl
	http-server /tmp/spki &> /dev/null &

	run create client_server test
	[ "$status" -eq 0 ]

	run ./spki revoke test keyCompromise <<-EOF
	$YES
	$INTERMEDIATE_PRIVATE_KEY_PASSWORD
	$ANYKEY
	EOF
	[ "$status" -eq 0 ]

	run ./spki verify test <<-EOF
	$ANYKEY
	EOF
	[ "$status" -eq 1 ]

	run ./spki list
	[ "$status" -eq 0 ]
	[[ "${lines[1]}" =~ "Status: Revoked" ]]
	[[ "${lines[4]}" =~ "Revocation reason: keyCompromise" ]]

	run ./spki list-crl
	[ "$status" -eq 0 ]
	[[ "${lines[30]}" =~ "Serial Number: 1000" ]]
	[[ "${lines[34]}" =~ "Key Compromise" ]]
	kill %%
}

@test "revoke intermediate" {
	init_from_input_crl

	run ./spki revoke-intermediate superseded <<-EOF
	$YES
	$ROOT_PRIVATE_KEY_PASSWORD
	$ANYKEY
	EOF
	[ "$status" -eq 0 ]

	run ./spki list-crl
	[ "$status" -eq 0 ]
	[[ "${lines[14]}" =~ "Serial Number: 1000" ]]
	[[ "${lines[18]}" =~ "Superseded" ]]
}