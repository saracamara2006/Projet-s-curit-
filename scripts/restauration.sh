#!/bin/bash
# Bloc 3.9 - Verification SHA256, dechiffrement a la volee et restauration en conteneur vierge
set -euo pipefail
cd "$(dirname "$0")/.."

PASS="secrets/backup_passphrase.txt"
BACKUP_DIR=$(ls -dt backups/20* 2>/dev/null | head -1 || true)

if [ -z "$BACKUP_DIR" ]; then
  echo "ERREUR : aucune sauvegarde trouvee dans backups/" >&2
  exit 1
fi

TMP_DIR=$(mktemp -d)
cleanup() {
  docker rm -f rh-restore-test >/dev/null 2>&1 || true
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "=== Restauration conteneur vierge (bloc 3.9) ==="
echo "Sauvegarde utilisee : $BACKUP_DIR"

echo ""
echo "--- 1. Verification integrite SHA256 ---"
( cd "$BACKUP_DIR" && sha256sum -c SHA256SUMS )

T0=$(date +%s)

echo ""
echo "--- 2. Preparation keyring et demarrage MySQL vierge ---"
mkdir -p "$TMP_DIR/keyring"
openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -pass file:"$PASS" \
  -in "$BACKUP_DIR/keyring.enc" -out "$TMP_DIR/keyring/component_keyring_file"
chmod 777 "$TMP_DIR/keyring"
chmod 666 "$TMP_DIR/keyring/component_keyring_file"

cat > "$TMP_DIR/mysqld.my" << 'EOF'
{ "components": "file://component_keyring_file" }
EOF
cat > "$TMP_DIR/component_keyring_file.cnf" << 'EOF'
{ "path": "/var/lib/mysql-keyring/component_keyring_file", "read_only": false }
EOF

docker rm -f rh-restore-test >/dev/null 2>&1 || true
docker run -d --name rh-restore-test \
  --env MYSQL_ROOT_PASSWORD=TestRestore123! \
  --network camara_sara_bdd_rhnet \
  -v "$TMP_DIR/mysqld.my:/usr/sbin/mysqld.my:ro" \
  -v "$TMP_DIR/component_keyring_file.cnf:/usr/lib64/mysql/plugin/component_keyring_file.cnf:ro" \
  -v "$TMP_DIR/keyring:/var/lib/mysql-keyring" \
  mysql:8.4 >/dev/null

echo "Attente demarrage MySQL vierge..."
for i in $(seq 1 40); do
  if docker exec rh-restore-test mysqladmin ping -uroot -pTestRestore123! --silent 2>/dev/null; then
    break
  fi
  sleep 3
done

echo ""
echo "--- 3. Dechiffrement a la volee et restauration ---"
openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -pass file:"$PASS" \
  -in "$BACKUP_DIR/rh_camara.sql.enc" \
  | docker exec -i rh-restore-test mysql -uroot -pTestRestore123!

T1=$(date +%s)

echo ""
echo "--- 4. Verification des donnees ---"
docker exec rh-restore-test mysql -uroot -pTestRestore123! rh_camara -t -e "
SELECT 'employes'    AS table_name, COUNT(*) AS lignes FROM employes
UNION ALL SELECT 'contrats',    COUNT(*) FROM contrats
UNION ALL SELECT 'salaires',    COUNT(*) FROM salaires
UNION ALL SELECT 'absences',    COUNT(*) FROM absences
UNION ALL SELECT 'evaluations', COUNT(*) FROM evaluations;
"

echo ""
echo "--- 5. Verification IV aleatoires (employe 1) et chiffrement au repos ---"
docker exec rh-restore-test mysql -uroot -pTestRestore123! rh_camara -t -e "
SELECT COUNT(*) AS mois, COUNT(DISTINCT salaire_brut_chiffre) AS iv_distincts_brut
FROM salaires WHERE employe_id = 1;
SELECT table_name, create_options
FROM information_schema.tables
WHERE table_schema = 'rh_camara' AND table_type = 'BASE TABLE';
"

echo ""
RTO=$((T1 - T0))
echo "RTO mesure : ${RTO}s (objectif cible : inferieur a 300s / 5 min)"
echo "RPO cible  : inferieur a 60s (sauvegarde + binlogs avant coupure)"
echo "=== Restauration terminee avec succes ==="
