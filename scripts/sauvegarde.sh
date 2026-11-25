#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TS=$(date +%Y%m%d_%H%M%S)
PASS=secrets/backup_passphrase.txt
[ -s "$PASS" ] || { umask 077; openssl rand -base64 48 > "$PASS"; }
chmod 600 "$PASS"
ENC() { openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt -pass file:"$PASS" "$@"; }
D=backups/$TS; mkdir -p "$D"; chmod 700 "$D"
R='MYSQL_PWD=$(cat /run/secrets/root_password)'
docker compose exec -T db sh -c "$R mysql -uroot -e 'FLUSH BINARY LOGS'"
docker compose exec -T db sh -c "$R mysqldump -uroot --single-transaction --routines --triggers --events --source-data=2 --databases rh_camara" | ENC -out "$D/rh_camara.sql.enc"
T=$(mktemp -d)
for f in $(docker compose exec -T db sh -c 'ls /var/lib/mysql/binlog.0*'); do docker compose cp "db:$f" "$T/" 2>/dev/null; done
tar -C "$T" -cf - . | ENC -out "$D/binlogs.tar.enc"
rm -rf "$T"
docker compose exec -T db cat /var/lib/mysql-keyring/component_keyring_file | ENC -out "$D/keyring.enc"
( cd "$D" && sha256sum *.enc > SHA256SUMS )
echo "Sauvegarde chiffree : $D"; ls -la "$D"
