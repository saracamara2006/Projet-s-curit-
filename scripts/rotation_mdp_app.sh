#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

NEW_PW="${1:-$(openssl rand -base64 18 | tr -d '/+=')Aa1#}"
OLD_PW=$(cat secrets/comptes/rh_camara_app.txt 2>/dev/null || true)

docker compose exec -T db sh -c 'MYSQL_PWD=$(cat /run/secrets/root_password) mysql -uroot' <<SQL
ALTER USER 'rh_camara_app'@'172.31.77.20'
  IDENTIFIED WITH caching_sha2_password BY '${NEW_PW}'
  RETAIN CURRENT PASSWORD;
SQL

echo "=== Connexion avec nouveau mot de passe ==="
MYSQL_PWD="${NEW_PW}" docker compose exec -T -e MYSQL_PWD client mysql -h db -urh_camara_app --ssl-ca=/etc/mysql/certs/ca.pem --ssl-mode=VERIFY_IDENTITY -e "SELECT CURRENT_USER();" -t

if [ -n "$OLD_PW" ]; then
  echo "=== Connexion avec ancien mot de passe (double mot de passe actif) ==="
  MYSQL_PWD="${OLD_PW}" docker compose exec -T -e MYSQL_PWD client mysql -h db -urh_camara_app --ssl-ca=/etc/mysql/certs/ca.pem --ssl-mode=VERIFY_IDENTITY -e "SELECT CURRENT_USER();" -t || true
fi

docker compose exec -T db sh -c 'MYSQL_PWD=$(cat /run/secrets/root_password) mysql -uroot' <<'SQL'
ALTER USER 'rh_camara_app'@'172.31.77.20' DISCARD OLD PASSWORD;
SQL
echo "=== Ancien mot de passe supprime ==="
(umask 077; printf '%s\n' "$NEW_PW" > secrets/comptes/rh_camara_app.txt)
