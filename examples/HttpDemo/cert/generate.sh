# generate CA

# Generate CA private key 
openssl genrsa -out ca.key 4096
# Generate CSR 
openssl req -new -key ca.key -out ca.csr
# Generate Self Signed certificate (CA)
openssl x509 -req -days 3650 -in ca.csr -signkey ca.key -out ca.crt
# OR
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt


# generate a certificate from CA for server
openssl genrsa -out server.key 4096
openssl req -new -key server.key -subj "/C=CN/ST=Shanghai/L=Shanghai/O=Putao/OU=HuntLabs/CN=www.huntlabs.net" -batch -out server.csr
openssl x509 -req -days 3650 -in server.csr -CA ca.crt -CAkey ca.key -set_serial 01 -out server.crt


# generate a certificate from CA for client
openssl genrsa -out client.key 4096
openssl req -new -key client.key -subj "/C=CN/ST=Shanghai/L=Shanghai/O=Putao/OU=HuntLabs/CN=web.huntlabs.net" -out client.csr
openssl x509 -req -days 3650 -in client.csr -CA ca.crt -CAkey ca.key -set_serial 01 -out client.crt
openssl pkcs12 -export -in client.crt -inkey client.key -out client.pfx

# verify 
openssl verify -CAfile ca.crt server.crt
openssl verify -CAfile ca.crt client.crt