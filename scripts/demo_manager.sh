#!/bin/bash
cd "$(dirname "$0")/.."
q() { MYSQL_PWD=$(cat "secrets/comptes/$1.txt") docker compose exec -T -e MYSQL_PWD client mysql -h db --ssl-mode=VERIFY_IDENTITY --ssl-ca=/etc/mysql/certs/ca.pem --ssl-mode=VERIFY_IDENTITY --ssl-ca=/etc/mysql/certs/ca.pem -u"$1" -e "$2" 2>&1; }
for m in mgr_dsi mgr_fin; do
  echo "===== $m ====="
  echo "-- sa vue equipe :"
  q $m "SELECT CURRENT_ROLE() AS role; SELECT COUNT(*) AS equipe, MIN(departement_id) AS dep FROM rh_camara.v_mon_equipe;"
  echo "-- lire les salaires (doit etre refuse) :"
  q $m "SELECT * FROM rh_camara.salaires LIMIT 1;"
  echo "-- lire la table employes (doit etre refuse) :"
  q $m "SELECT * FROM rh_camara.employes LIMIT 1;"
done
