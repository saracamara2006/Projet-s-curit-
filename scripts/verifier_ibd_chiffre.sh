#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

{
  echo "=== Verification tables chiffrees au repos ==="
  docker compose exec -T db sh -c 'MYSQL_PWD=$(cat /run/secrets/root_password) mysql -uroot -t' <<'SQL'
SELECT @@default_table_encryption AS tables_defaut,
       @@innodb_redo_log_encrypt AS redo_chiffre,
       @@innodb_undo_log_encrypt AS undo_chiffre,
       @@binlog_encryption AS binlog_chiffre;
SELECT table_name, create_options FROM information_schema.tables
 WHERE table_schema='rh_camara' AND table_type='BASE TABLE';
SQL

  echo "=== Recherche chaines en clair dans employes.ibd (attendu : 0) ==="
  docker compose exec -T db grep -caoE 'Alaoui|Bennani|EMP-[0-9]{5}|@entreprise\.example' /var/lib/mysql/rh_camara/employes.ibd || true

  echo "=== Recherche chaines en clair dans salaires.ibd (attendu : 0) ==="
  docker compose exec -T db grep -caoE '11271\.00|8791\.38|32000\.00' /var/lib/mysql/rh_camara/salaires.ibd || true
}
