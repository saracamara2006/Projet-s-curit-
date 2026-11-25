#!/bin/bash
cd "$(dirname "$0")/.."
K=$(<secrets/cle_salaire.hex); MAUV=$(printf '00%.0s' $(seq 1 32))
u() {
  echo "  > $2" | sed "s/${K}/<CLE_AES_256>/g; s/${MAUV}/<MAUVAISE_CLE>/g"
  echo "$2" | MYSQL_PWD=$(cat "secrets/comptes/$1.txt") docker compose exec -T -e MYSQL_PWD client mysql -h db --ssl-mode=VERIFY_IDENTITY --ssl-ca=/etc/mysql/certs/ca.pem --ssl-mode=VERIFY_IDENTITY --ssl-ca=/etc/mysql/certs/ca.pem -u"$1" -t 2>&1 | sed 's/^/  /'
}
echo "== paie lit les salaires de l'employe 9 via la procedure (attendu : 12 mois, brut 11271.00, net 8791.38)"
u paie_camara "CALL rh_camara.sp_lire_salaires(9, UNHEX('$K'));"
echo "== paie avec une MAUVAISE cle (attendu : ERROR 1644 dechiffrement impossible)"
u paie_camara "CALL rh_camara.sp_lire_salaires(9, UNHEX('$MAUV'));"
echo "== paie ecrit via la procedure (memes montants : donnee inchangee, nouvel IV)"
u paie_camara "CALL rh_camara.sp_ecrire_salaire(9, '2025-10-01', 11271.00, 0.00, UNHEX('$K'));"
echo "== paie lit la table directement (attendu : ERROR 1142)"
u paie_camara "SELECT * FROM rh_camara.salaires LIMIT 1;"
echo "== drh lit la table (attendu : ERROR 1142) puis appelle la procedure (attendu : ERROR 1370)"
u drh_camara "SELECT * FROM rh_camara.salaires LIMIT 1;"
u drh_camara "CALL rh_camara.sp_lire_salaires(9, UNHEX('$K'));"
echo "== manager et gestionnaire : procedure refusee (attendu : ERROR 1370)"
u mgr_dsi "CALL rh_camara.sp_lire_salaires(9, UNHEX('$K'));"
u gest_camara "CALL rh_camara.sp_lire_salaires(9, UNHEX('$K'));"
