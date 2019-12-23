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
	dump_output_on_fail
	[ "$status" -eq 1 ]
	[ "${lines[0]}" = "Usage:" ]
}

@test "init creates a root and intermediate cert with the right DNs" {
	run init_from_input
	dump_output_on_fail
	[ "$status" -eq 0 ]

	ROOTCERT=$(openssl x509 -in /tmp/spki/certs/ca.cert.pem -noout -text)
	echo "$ROOTCERT" | grep "Issuer: CN = Root CA, C = PL, ST = Warsaw, L = Warsaw, O = Company Ltd, OU = Developers, emailAddress = mail@company.com" &> /dev/null
	echo "$ROOTCERT" | grep "Subject: CN = Root CA, C = PL, ST = Warsaw, L = Warsaw, O = Company Ltd, OU = Developers, emailAddress = mail@company.com" &> /dev/null
	INTRMDTCERT=$(openssl x509 -in /tmp/spki/intermediate/certs/intermediate.cert.pem -noout -text)
	echo "$INTRMDTCERT" | grep "Issuer: CN = Root CA, C = PL, ST = Warsaw, L = Warsaw, O = Company Ltd, OU = Developers, emailAddress = mail@company.com" &> /dev/null
	echo "$INTRMDTCERT" | grep "Subject: CN = $INTERMEDIATE_COMMON_NAME, C = PL, ST = Warsaw, L = Warsaw, O = Company Ltd, OU = Developers, emailAddress = mail@company.com" &> /dev/null
}

@test "init with config file overwrites file and env vars" {
	export SPKI_CONFIG_FILE="test/config"
	export SPKI_ROOT_PREFIX="test"
	run init_from_input
	dump_output_on_fail
	[ "$status" -eq 0 ]
	[ -f  /tmp/spki/certs/ca_filetest.cert.pem ]
	[ -f  /tmp/spki/private/ca_filetest.key.pem ]
	[ -f /tmp/spki/intermediate/certs/intermediate_filetest.cert.pem ]
	[ -f /tmp/spki/intermediate/private/intermediate_filetest.key.pem ]
}

@test "conf defaults get set properly from user input" {
	run init_from_input
	dump_output_on_fail
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
	dump_output_on_fail
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
	init_from_input
	dump_output_on_fail
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
	init_from_input

	run create user test
	dump_output_on_fail
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
	init_from_input

	run create client_server test
	dump_output_on_fail
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
	init_from_input

	create client_server test

	run ./spki verify test<<<"$ANYKEY"
	dump_output_on_fail
	[ "$status" -eq 0 ] # by prefix

	run ./spki verify "/tmp/spki/intermediate/certs/test.cert.pem"<<<"$ANYKEY"
	dump_output_on_fail
	[ "$status" -eq 0 ] # by filename
}

@test "sign" {
	init_from_input
	create_csr

	CERT="/tmp/spki/intermediate/certs/test.cert.pem"
	run ./spki sign client_server "$CSR" "$CERT" <<-EOF
	$INTERMEDIATE_PRIVATE_KEY_PASSWORD
	$YES
	$YES
	$ANYKEY
	EOF
	dump_output_on_fail
	[ "$status" -eq 0 ]
	[ -f "/tmp/spki/intermediate/certs/test.cert.pem" ]
}

@test "export to pkcs12" {
	init_from_input
	create client_server test

	run ./spki export-pkcs12 test <<-EOF
	$PRIVATE_KEY_PASSWORD
	$PRIVATE_KEY_PASSWORD
	EOF
	dump_output_on_fail
	[ "$status" -eq 0 ]
	[ -f "/tmp/spki/intermediate/certs/test.p12" ]
}

@test "export to trust store" {
	command -v keytool
	init_from_input
	create client_server test

	run ./spki export-truststore test <<-EOF
	$PRIVATE_KEY_PASSWORD
	$PRIVATE_KEY_PASSWORD
	EOF
	dump_output_on_fail
	[ "$status" -eq 0 ]
	[ -f "/tmp/spki/intermediate/certs/test_truststore.p12" ]
}

@test "list" {
	init_from_input
	create client_server test

	run ./spki list
	dump_output_on_fail
	[ "$status" -eq 0 ]
	# Bash test + regex avoids whitespace issues
	[[ "${lines[0]}" =~ "/CN=$CERT_COMMON_NAME/C=$countryName/ST=$stateOrProvinceName/L=$localityName/O=$organizationName/OU=$organizationalUnitName/emailAddress=$emailAddress" ]]
	[[ "${lines[1]}" =~ "Status: Valid" ]]
	[[ "${lines[3]}" =~ "Serial: 1000" ]]
}

@test "generate crl" {
	start-http-server
	run init_from_input_crl
	dump_output_on_fail
	[ "$status" -eq 0 ]
	[ -f "/tmp/spki/crl/ca.crl.der" ]
	[ -f "/tmp/spki/intermediate/crl/intermediate.crl.der" ]

	run ./spki generate-crl <<-EOF
	$INTERMEDIATE_PRIVATE_KEY_PASSWORD

	$ANYKEY
	EOF
	dump_output_on_fail
	[ "$status" -eq 0 ]

	run ./spki generate-crl -rootca <<-EOF
	$ROOT_PRIVATE_KEY_PASSWORD

	$ANYKEY
	EOF
	dump_output_on_fail
	[ "$status" -eq 0 ]

	kill-http-server
}

@test "list-crl" {
	start-http-server
	init_from_input_crl
	run ./spki list-crl
	dump_output_on_fail
	[ "$status" -eq 0 ]
	[[ "${lines[1]}" =~ "Certificate Revocation List (CRL):" ]]
	[[ "${lines[2]}" =~ "Version 2 (0x1)" ]]
	[[ "${lines[3]}" =~ "Signature Algorithm: sha256WithRSAEncryption" ]]
	[[ "${lines[4]}" =~ "Issuer: CN = $ROOT_COMMON_NAME, C = PL, ST = Warsaw, L = Warsaw, O = Company Ltd, OU = Developers, emailAddress = mail@company.com" ]]

	[[ "${lines[16]}" =~ "Certificate Revocation List (CRL):" ]]
	[[ "${lines[17]}" =~ "Version 2 (0x1)" ]]
	[[ "${lines[18]}" =~ "Signature Algorithm: sha256WithRSAEncryption" ]]
	[[ "${lines[19]}" =~ "Issuer: CN = $INTERMEDIATE_COMMON_NAME, C = PL, ST = Warsaw, L = Warsaw, O = Company Ltd, OU = Developers, emailAddress = mail@company.com" ]]
	kill-http-server
}

@test "create and revoke cert (crl)" {
	start-http-server
	init_from_input_crl

	run create client_server test
	dump_output_on_fail
	[ "$status" -eq 0 ]

	run revoke test
	dump_output_on_fail
	[ "$status" -eq 0 ]

	run ./spki verify test <<-EOF
	$ANYKEY
	EOF
	dump_output_on_fail
	[ "$status" -eq 1 ]

	run ./spki list
	dump_output_on_fail
	[ "$status" -eq 0 ]
	[[ "${lines[1]}" =~ "Status: Revoked" ]]
	[[ "${lines[4]}" =~ "Revocation reason: keyCompromise" ]]

	run ./spki list-crl
	dump_output_on_fail
	[ "$status" -eq 0 ]
	[[ "${lines[29]}" =~ "Serial Number: 1000" ]]
	[[ "${lines[33]}" =~ "Key Compromise" ]]
	kill-http-server
}

@test "revoke intermediate" {
	start-http-server
	init_from_input_crl

	run ./spki revoke-intermediate superseded <<-EOF
	$YES
	$ROOT_PRIVATE_KEY_PASSWORD
	$ANYKEY
	EOF
	dump_output_on_fail
	[ "$status" -eq 0 ]

	run ./spki list-crl
	dump_output_on_fail
	[ "$status" -eq 0 ]
	[[ "${lines[14]}" =~ "Serial Number: 1000" ]]
	[[ "${lines[18]}" =~ "Superseded" ]]

	# this doesn't actually check the CRL DP
	# since it looks it up in the local database first
	run ./spki verify-intermediate
	dump_output_on_fail
	[ "$status" -eq 1 ]

	kill-http-server
}

@test "generate ocsp signing pairs" {
	run init_from_input_ocsp
	dump_output_on_fail
	[ "$status" -eq 0 ]
	[ -f "/tmp/spki/certs/ca.ocsp.cert.pem" ]
	[ -f "/tmp/spki/intermediate/certs/intermediate.ocsp.cert.pem" ]

	ROOT_OCSP_CERT=$(openssl x509 -in /tmp/spki/certs/ca.ocsp.cert.pem -noout -text)
	echo "$ROOT_OCSP_CERT" | grep "Issuer: CN = $ROOT_COMMON_NAME, C = PL, ST = Warsaw, L = Warsaw, O = Company Ltd, OU = Developers, emailAddress = mail@company.com"
	echo "$ROOT_OCSP_CERT" | grep "Subject: CN = $ROOT_OCSP_COMMON_NAME, C = PL, ST = Warsaw, L = Warsaw, O = Company Ltd, OU = Developers, emailAddress = mail@company.com"

	INTERMEDIATE_OCSP_CERT=$(openssl x509 -in /tmp/spki/intermediate/certs/intermediate.ocsp.cert.pem -noout -text)
	echo "$INTERMEDIATE_OCSP_CERT" | grep "Issuer: CN = $INTERMEDIATE_COMMON_NAME, C = PL, ST = Warsaw, L = Warsaw, O = Company Ltd, OU = Developers, emailAddress = mail@company.com"
	echo "$INTERMEDIATE_OCSP_CERT" | grep "Subject: CN = $INTERMEDIATE_OCSP_COMMON_NAME, C = PL, ST = Warsaw, L = Warsaw, O = Company Ltd, OU = Developers, emailAddress = mail@company.com"
}

@test "ocsp responder" { #can't start the ocsp responder programmaticaly because there's no -passin arg
	skip
	init_from_input_ocsp
	./spki ocsp-responder 12345 &> /dev/null & <<-EOF
	$INTERMEDIATE_PRIVATE_KEY_PASSWORD
	EOF

	create client_server test
	run ./spki ocsp-query http://localhost:12345 test
	dump_output_on_fail
	[ "$status" -eq 0 ]

	revoke test
	kill %%
}
