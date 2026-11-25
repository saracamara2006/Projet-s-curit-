#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p secrets/comptes && chmod 700 secrets/comptes
HOST='172.31.77.20'
mysql_root() { docker compose exec -T db sh -c 'MYSQL_PWD=$(cat /run/secrets/root_password) mysql -uroot'; }

creer() {
  local u="$1" r="$2" f="secrets/comptes/$1.txt"
  if [ ! -f "$f" ]; then
    echo "$(openssl rand -base64 18 | tr -d '/+=')Aa1#" > "$f"
    chmod 600 "$f"
  fi
  cat <<SQL | mysql_root
CREATE USER IF NOT EXISTS '$u'@'$HOST' IDENTIFIED WITH caching_sha2_password BY '$(cat "$f")' FAILED_LOGIN_ATTEMPTS 5 PASSWORD_LOCK_TIME 1;
GRANT '$r' TO '$u'@'$HOST';
SET DEFAULT ROLE '$r' TO '$u'@'$HOST';
SQL
  echo "OK : $u -> $r"
}

creer drh_camara     role_drh
creer gest_camara    role_gestionnaire_rh
creer paie_camara    role_paie
creer audit_camara   role_auditeur_rh
creer backup_camara  role_sauvegarde
creer monitor_camara role_supervision
creer mgr_dsi        role_manager
creer mgr_fin        role_manager

cat <<SQL | mysql_root
REVOKE SELECT ON rh_camara.departements FROM 'rh_camara_app'@'$HOST';
GRANT 'role_gestionnaire_rh' TO 'rh_camara_app'@'$HOST';
SET DEFAULT ROLE 'role_gestionnaire_rh' TO 'rh_camara_app'@'$HOST';
SQL
echo "OK : rh_camara_app -> role_gestionnaire_rh"
