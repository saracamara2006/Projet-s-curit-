#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
DB_IP=$(docker compose exec -T db sh -c 'getent hosts db | awk "{print \$1}"' 2>/dev/null || true)
mkdir -p certs
openssl genrsa -out certs/ca-key.pem 4096
openssl req -x509 -new -nodes -key certs/ca-key.pem -sha256 -days 365 -subj "/CN=Projet-RH-CA" -out certs/ca.pem

openssl genrsa -out certs/server-key.pem 2048
cat > certs/server-san.cnf <<SAN
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no
[req_distinguished_name]
CN = db
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = db
DNS.2 = localhost
IP.1 = 127.0.0.1
${DB_IP:+IP.2 = $DB_IP}
SAN
openssl req -new -key certs/server-key.pem -config certs/server-san.cnf -out certs/server.csr
openssl x509 -req -in certs/server.csr -CA certs/ca.pem -CAkey certs/ca-key.pem -CAcreateserial -out certs/server-cert.pem -days 365 -sha256 -extensions v3_req -extfile certs/server-san.cnf

openssl genrsa -out certs/client-key.pem 2048
openssl req -new -key certs/client-key.pem -subj "/CN=rh-client" -out certs/client.csr
openssl x509 -req -in certs/client.csr -CA certs/ca.pem -CAkey certs/ca-key.pem -CAcreateserial -out certs/client-cert.pem -days 365 -sha256

chmod 644 certs/*.pem certs/*.cnf certs/*.csr 2>/dev/null || true
chmod 600 certs/*-key.pem
docker run --rm -v "$PWD/certs":/certs --entrypoint chown mysql:8.4 -R 999:999 /certs
chmod 600 certs/*-key.pem
openssl x509 -in certs/server-cert.pem -noout -subject -ext subjectAltName
