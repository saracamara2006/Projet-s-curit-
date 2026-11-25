# Plateforme MySQL 8.4 LTS durcie, chiffrée et conforme : variante D (Ressources humaines)

**Étudiante :** CAMARA Sara, B3 Cybersécurité, Maroc Ynov Campus
**Enseignant :** M. Hamza ESSAD, module « Administration et sécurité des bases de données »
**Schéma :** `rh_camara` (variante D : `rh_<nom>`)
**Cadre réglementaire :** loi marocaine 09-08 (protection des données à caractère personnel)
**Environnement de réalisation :** VM Ubuntu (VMware), Docker Compose v2, MySQL 8.4.13

Le dépôt suit l'arborescence demandée par le sujet. Chaque mesure renvoie à une preuve (commande et résultat) dans `preuves/`. Les bonus 3.5, 3.7 et 3.8 ne sont pas traités (voir section 11).

---

## Contrainte de la variante D

> Un manager ne voit que son équipe et jamais les salaires ; le salaire est chiffré au niveau colonne (AES-256-CBC, vecteur d'initialisation aléatoire) en plus du chiffrement au repos.

| Exigence | Réalisation | Preuve |
|---|---|---|
| Un manager ne voit que son équipe | Vues `v_mon_equipe` et `v_absences_equipe` en `SQL SECURITY DEFINER`. Le filtre compare `employes.compte_mysql` du manager à `USER()` (le compte connecté). `role_manager` n'a aucun droit sur les tables. `mgr_dsi` et `mgr_fin` voient 149 employés chacun (départements 1 et 2). | `preuves/13_demo_manager.txt` |
| Un manager ne voit jamais les salaires | `SELECT` sur `salaires` : erreur 1142. Appel de `sp_lire_salaires` : erreur 1370. | `preuves/13_demo_manager.txt`, `preuves/16b_test_salaires.txt` |
| Salaire chiffré au niveau colonne | `salaire_brut`, `primes` et `net_a_payer` sont chiffrés en AES-256-CBC avec un IV de 16 octets (`RANDOM_BYTES(16)`) stocké devant le chiffré (`VARBINARY(64)`). Les colonnes en clair sont supprimées après un contrôle de migration (14 400 lignes). | `preuves/15b_migration_chiffrement.txt`, `preuves/16b_test_salaires.txt` |
| En plus du chiffrement au repos | Keyring fichier, tables en `ENCRYPTION='Y'`, redo, undo et binlog chiffrés. | `preuves/17b_preuve_ibd.txt`, `preuves/35_au_repos.txt`, `preuves/36_ibd.txt` |

---

## 1. Architecture (bloc 3.1)

```
        Hôte (VM Ubuntu) : aucun port MySQL publié
 ┌─────────────────────────────────────────────────────────────┐
 │  Réseau Docker privé « rhnet » 172.31.77.0/24               │
 │                                                             │
 │  ┌──────────────────┐   TLS 1.2 / 1.3   ┌────────────────┐  │
 │  │ rh-client        │ ────────────────► │ rh-db          │  │
 │  │ 172.31.77.20     │   3306 (interne)  │ 172.31.77.10   │  │
 │  │ client mysql     │                   │ mysql:8.4      │  │
 │  │ seul hôte des    │                   │ base rh_camara │  │
 │  │ comptes          │                   └───────┬────────┘  │
 │  └──────────────────┘                           │           │
 │                              volume dbdata (données)        │
 │                              dossier keyring_data (clés)    │
 └─────────────────────────────────────────────────────────────┘
```

- `docker-compose.yml` définit deux services : `db` (conteneur `rh-db`) et `client` (conteneur `rh-client`).
- **Aucun port publié** : le service `db` n'a pas de section `ports:`. Dans `preuves/01_ps_aucun_port.txt`, la colonne PORTS affiche `3306/tcp` sans flèche `->` : le port est déclaré par l'image, pas publié sur l'hôte.
- Le mot de passe root est un secret Docker (`MYSQL_ROOT_PASSWORD_FILE`), pas une variable d'environnement en clair.
- Montages en lecture seule : `conf/mysql.cnf`, `certs/`, `conf/mysqld.my`, `conf/component_keyring_file.cnf`. Le keyring est dans `keyring_data/`, séparé du volume de données `dbdata`.
- Le client monte aussi le kit du cours (`/home/sara/kit` vers `/kit`, lecture seule) ; ce montage est facultatif et à adapter ou retirer si le kit est ailleurs.

## 2. Démarrage pas à pas

**Prérequis :** Docker Engine et Docker Compose v2, `openssl`, `bash`. Le dossier du projet doit s'appeler `CAMARA_Sara_BDD` : `scripts/restauration.sh` utilise le réseau `camara_sara_bdd_rhnet`, dont le nom vient du dossier. Si le kit du cours est ailleurs que `/home/sara/kit`, adaptez ou retirez cette ligne dans `docker-compose.yml`.

Pour exécuter un fichier SQL en root (le mot de passe est lu dans le secret Docker, jamais tapé en clair) :
```bash
docker compose exec -T db sh -c 'MYSQL_PWD=$(cat /run/secrets/root_password) mysql -uroot' < sql/FICHIER.sql
```

1. **Secrets** (jamais versionnés ; les fichiers `*.example` donnent le format) :
   ```bash
   mkdir -p secrets/comptes certs keyring_data backups
   cp secrets/root_password.txt.example  secrets/root_password.txt    # remplacer par un mot de passe fort
   cp secrets/admin_password.txt.example secrets/admin_password.txt   # idem (compte admin_camara)
   openssl rand -hex 32 > secrets/cle_salaire.hex                     # clé AES-256 (64 caractères hexadécimaux)
   chmod 700 secrets/comptes && chmod 600 secrets/*.txt secrets/*.hex
   ```
2. **Certificats TLS** : `bash scripts/generer_tls.sh` (CA du projet, certificat serveur avec SAN, certificat client `CN=rh-client`).
3. **Dossier du keyring** (utilisateur `mysql` de l'image = UID 999) :
   ```bash
   docker run --rm -v "$PWD/keyring_data":/k --entrypoint chown mysql:8.4 -R 999:999 /k
   docker run --rm -v "$PWD/keyring_data":/k --entrypoint chmod mysql:8.4 700 /k
   ```
4. **Démarrage** : `docker compose up -d`. Le dépôt contient déjà la configuration du keyring (`conf/mysqld.my`, `conf/component_keyring_file.cnf`, montages du compose) : le composant se charge dès le premier démarrage. Ne relancez pas `scripts/activer_keyring.sh`, qui a servi à mettre cette configuration en place et refuse de s'exécuter sur un compose déjà modifié.
5. **Base et données** : `CREATE DATABASE rh_camara CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;` puis `sql/01_D_rh.sql` (schéma et données fictives, 1 200 employés et 14 400 lignes de salaires), exécuté dans la base :
   ```bash
   docker compose exec -T db sh -c 'MYSQL_PWD=$(cat /run/secrets/root_password) mysql -uroot rh_camara' < sql/01_D_rh.sql
   ```
6. **Authentification** : `sql/02_auth.sql`. **Rôles et vues** : `sql/03_roles.sql`.
7. **Durcissement des comptes** : `sql/04_root_localhost.sql`. **Admin nominatif** : `sql/05_admin_nominatif.sql` (mot de passe lu dans `secrets/admin_password.txt`).
8. **Comptes techniques et applicatif** (aucun script ne les crée ; à exécuter avant l'étape 9) :
   ```sql
   CREATE USER 'rh_crypto_owner'@'%' IDENTIFIED WITH caching_sha2_password BY RANDOM PASSWORD ACCOUNT LOCK;
   -- compte applicatif : mot de passe dans secrets/comptes/rh_camara_app.txt
   CREATE USER 'rh_camara_app'@'172.31.77.20' IDENTIFIED WITH caching_sha2_password BY '<mot de passe>'
     FAILED_LOGIN_ATTEMPTS 3 PASSWORD_LOCK_TIME 1;
   GRANT SELECT ON rh_camara.departements TO 'rh_camara_app'@'172.31.77.20';
   ```
9. **Comptes nominatifs** : `bash scripts/creer_comptes.sh` (génère les mots de passe dans `secrets/comptes/`, crée les 8 comptes, relie `rh_camara_app` au rôle `role_gestionnaire_rh`).
10. **Chiffrement des salaires** : `sql/20_chiffrement_salaires.sql`, avec la clé injectée à l'exécution à la place de `@@CLE@@` :
    ```bash
    sed "s/@@CLE@@/$(cat secrets/cle_salaire.hex)/" sql/20_chiffrement_salaires.sql | docker compose exec -T db sh -c 'MYSQL_PWD=$(cat /run/secrets/root_password) mysql -uroot'
    ```
    Puis `sql/21_routines_salaires.sql`. (`sql/20b_reprise_migration.sql` ne sert que si la migration a été interrompue.)
11. **Compte à certificat client** (mot de passe dans `secrets/comptes/tls_client_camara.txt`) :
    ```sql
    CREATE USER 'tls_client_camara'@'172.31.77.20' IDENTIFIED BY '<mot de passe>' REQUIRE SUBJECT '/CN=rh-client';
    GRANT SELECT ON rh_camara.departements TO 'tls_client_camara'@'172.31.77.20';
    ```
12. **Vérifications** : `bash scripts/demo_manager.sh`, `bash scripts/test_salaires.sh`, `bash scripts/verifier_ibd_chiffre.sh`.
13. **Sauvegarde et restauration** : `bash scripts/sauvegarde.sh`, puis `bash scripts/restauration.sh` (section 7).

## 3. Durcissement du serveur (bloc 3.2)

| Exigence du sujet | Mesure | Preuve |
|---|---|---|
| Configuration versionnée : X Protocol désactivé, `skip_name_resolve`, `local_infile` désactivé, `secure_file_priv` restreint, `sql_mode` strict | `conf/mysql.cnf` : `mysqlx=OFF`, `skip_name_resolve=ON`, `local_infile=OFF`, `secure_file_priv=/var/lib/mysql-files`, `sql_mode=ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION` | `02_durcissement.txt`, `02b_x_protocol.txt`, `31_durcissement.txt` |
| Journal général désactivé, journaux d'erreurs et lent actifs | `general_log=OFF` (il enregistrerait les requêtes, donc des données personnelles) ; `slow_query_log=ON` avec `long_query_time=1` ; journal d'erreurs actif (`log_error_verbosity=2`) | `31_durcissement.txt`, `conformite/rapport_audit_apres.txt` |
| Aucun compte anonyme, pas de base `test`, root uniquement en local | `sql/04_root_localhost.sql` supprime les `root` hors `localhost`. Liste des comptes et des bases : aucun anonyme, pas de base `test`. | `03_comptes_avant.txt`, `03_comptes_apres.txt`, `04_root_refuse.txt`, `04b_root_localhost.txt`, `31_durcissement.txt` |
| Un compte d'administration nominatif | `admin_camara@localhost` (`sql/05_admin_nominatif.sql`) : administrateur limité à la machine du serveur, pour savoir qui a fait quoi. | `04_admin_ok.txt`, `05b_admin_nominatif.txt` |
| Secrets fournis par fichiers, droits justifiés | Mot de passe root : secret Docker. Fichiers de `secrets/` en mode 600, dossier `secrets/comptes` en 700 (un secret lisible par un autre utilisateur n'est plus secret). Clés privées TLS en 600 appartenant à l'UID 999. Dossier du keyring en 700, propriétaire 999 (seul l'utilisateur `mysql` y accède). | `scripts/generer_tls.sh`, `scripts/creer_comptes.sh` |

## 4. Authentification (bloc 3.3)

| Exigence du sujet | Mesure | Preuve |
|---|---|---|
| `caching_sha2_password` pour tous les comptes | Plugin par défaut de MySQL 8.4, indiqué explicitement dans les `CREATE USER` des scripts. | `05b_admin_nominatif.txt` (colonne `plugin`), `scripts/creer_comptes.sh` |
| `validate_password` configuré et justifié | `sql/02_auth.sql` : politique STRONG, 14 caractères minimum, 1 majuscule, 1 chiffre, 1 caractère spécial, nom d'utilisateur interdit. Justification : données personnelles de salariés, les mots de passe faibles sont la première cause de compromission. Le mot de passe `123456` est refusé. | `05_validate_password.txt`, `06_mdp_faible_refuse.txt` |
| Cycle de vie : expiration, historique, mot de passe actuel requis | `default_password_lifetime=90`, `password_history=5`, `password_reuse_interval=365`, `password_require_current=ON` (posés par `SET PERSIST`, donc stockés dans le volume de données et rejoués par `sql/02_auth.sql`). Les comptes héritent de l'expiration à 90 jours, sauf le compte applicatif `rh_camara_app` (`password_lifetime=0`, il n'expire pas) : une expiration brutale couperait l'application ; son mot de passe est renouvelé volontairement par la rotation à double mot de passe. | `32_auth.txt`, `11_auth_rotation.txt` |
| Verrouillage après échecs | Les 8 comptes créés par `creer_comptes.sh` : `FAILED_LOGIN_ATTEMPTS 5 PASSWORD_LOCK_TIME 1` (un jour). Le compte applicatif `rh_camara_app` est réglé à 3 échecs : à la 3e tentative ratée, `ERROR 3955 … Account is blocked for 1 day(s)`, même avec le bon mot de passe ensuite. | `08_verrouillage.txt`, `08b_deverrouillage.txt` |
| Rotation sans coupure (double mot de passe), démontrée | `scripts/rotation_mdp_app.sh` : `ALTER USER … RETAIN CURRENT PASSWORD` (l'ancien et le nouveau fonctionnent), mise à jour de l'application, puis `DISCARD OLD PASSWORD`. | `09_rotation_double.txt` (les deux marchent), `10_rotation_fin.txt` (l'ancien échoue), `11b_rotation_script.txt` |

## 5. Contrôle d'accès par rôles (bloc 3.4)

### Matrice rôles × privilèges (état final, vérifié par `SHOW GRANTS … USING`)

| Rôle | Privilèges |
|---|---|
| `role_drh` | `SELECT`, `INSERT`, `UPDATE` sur `employes`, `departements`, `contrats`, `absences`, `evaluations`. Aucun droit sur `salaires`. |
| `role_gestionnaire_rh` | `SELECT`, `INSERT`, `UPDATE` sur `contrats` et `absences` ; `SELECT` sur `departements` ; sur `employes` : `SELECT`, `INSERT` limité à 12 colonnes et `UPDATE` limité à 6 colonnes (`adresse`, `departement_id`, `email_pro`, `manager_id`, `poste`, `telephone`). Ni `cin`, ni `compte_mysql` modifiables. |
| `role_paie` | `SELECT` sur 5 colonnes de `employes` (`id`, `matricule`, `nom`, `prenom`, `departement_id`) ; `EXECUTE` sur `sp_ecrire_salaire` et `sp_lire_salaires`. Aucun droit direct sur `salaires`. |
| `role_manager` | `SELECT` sur `v_mon_equipe` et `v_absences_equipe` uniquement. |
| `role_auditeur_rh` | `SELECT` sur `departements`, `contrats`, `absences`. |
| `role_sauvegarde` | `SELECT`, `SHOW VIEW`, `LOCK TABLES` sur `rh_camara` ; `RELOAD`, `PROCESS`, `REPLICATION CLIENT`, `BACKUP_ADMIN` au niveau global (le minimum que demande une sauvegarde cohérente). |
| `role_supervision` | `PROCESS`, `REPLICATION CLIENT` ; `SELECT` sur `performance_schema` et `sys`. Aucune donnée métier. |

Cela fait **5 rôles métier** (drh, gestionnaire_rh, paie, manager, auditeur_rh), plus un rôle de sauvegarde et un rôle de supervision.

### Comptes (les mots de passe sont dans `secrets/comptes/`, non fournis)

| Compte | Hôte | Rôle par défaut / fonction |
|---|---|---|
| `drh_camara` | 172.31.77.20 | `role_drh` |
| `gest_camara` | 172.31.77.20 | `role_gestionnaire_rh` |
| `rh_camara_app` (applicatif) | 172.31.77.20 | `role_gestionnaire_rh` |
| `paie_camara` | 172.31.77.20 | `role_paie` |
| `mgr_dsi`, `mgr_fin`, `mgr_rh`, `mgr_com`, `mgr_mkt`, `mgr_log`, `mgr_jur`, `mgr_prod` | 172.31.77.20 | `role_manager` (un compte par département, relié à `employes.compte_mysql`) |
| `audit_camara` | 172.31.77.20 | `role_auditeur_rh` |
| `backup_camara` | 172.31.77.20 | `role_sauvegarde` |
| `monitor_camara` | 172.31.77.20 | `role_supervision` |
| `tls_client_camara` | 172.31.77.20 | `SELECT` sur `departements` ; certificat client exigé |
| `admin_camara` | localhost | administrateur nominatif (`ALL PRIVILEGES … WITH GRANT OPTION`, limité à la machine du serveur) |
| `root` | localhost | administration locale |
| `rh_view_owner` | % | propriétaire des vues, **verrouillé** (`ACCOUNT LOCK`) |
| `rh_crypto_owner` | % | propriétaire des fonctions et procédures de chiffrement, **verrouillé** |
| `role_*` (7 rôles) | % | rôles, donc comptes verrouillés par nature |

Les comptes en `%` sont tous verrouillés : l'hôte `%` n'ouvre aucun accès réseau. L'audit du kit les signale (contrôle A08) ; écart accepté et justifié.

### Règles appliquées

- **Comptes limités par adresse** : les comptes applicatifs et nominatifs ne fonctionnent que depuis 172.31.77.20 (possible parce que `skip_name_resolve` est actif). **Rôles par défaut** définis avec `SET DEFAULT ROLE` : sans cela, un rôle accordé n'est pas actif à la connexion.
- **Aucun privilège global, ni `FILE`, ni `GRANT OPTION` pour les comptes applicatifs et métier.** Seuls `root` et `admin_camara` (locaux au serveur) ont `GRANT OPTION` ; les seuls privilèges globaux hors administration sont ceux, minimaux, de `role_sauvegarde` et `role_supervision`.
- **Restriction par colonne** : `role_paie` (5 colonnes de `employes`) et `role_gestionnaire_rh` (écriture sur `employes` limitée à certaines colonnes ; refus de modifier `cin` et `compte_mysql`).
- **Vues en `SQL SECURITY DEFINER`** avec un propriétaire dédié et verrouillé (`rh_view_owner`). Le filtre utilise `USER()` et non `CURRENT_USER()` : dans une vue `DEFINER`, `CURRENT_USER()` renverrait le propriétaire de la vue, pas le manager connecté.
- **Vérification compte par compte** avec `SHOW GRANTS … USING`.

Preuves : `11_roles_et_vues.txt`, `12_roles_par_defaut.txt`, `12b_show_grants_using.txt`, `12c_nettoyage_et_durcissement_roles.txt`, `12d_test_gestionnaire.txt`, `33_grants_roles.txt`, `48_tous_les_managers.txt`. La mise au point des vues est documentée dans `11b_correction_definer.txt` à `11f_proprietaire_colonnes.txt` (voir limite n° 4).

## 6. Chiffrement en transit et au repos (bloc 3.6)

| Exigence du sujet | Mesure | Preuve |
|---|---|---|
| Autorité de certification du projet, certificats serveur avec SAN | `scripts/generer_tls.sh` : CA `Projet-RH-CA` (RSA 4096), certificat serveur dont le SAN contient `db`, `localhost`, `127.0.0.1` et l'IP du serveur, certificat client `CN=rh-client`. Validité de 365 jours. | `certs/` (certificats seulement), `37_tls.txt` |
| `require_secure_transport`, TLS 1.2 et 1.3 uniquement | `require_secure_transport=ON` et `tls_version=TLSv1.2,TLSv1.3` dans `conf/mysql.cnf`. Une connexion sans TLS est refusée (erreur 3159). L'état avant activation est conservé dans `18a_etat_tls.txt`. | `18a_etat_tls.txt`, `18b_tls_actif.txt`, `37_tls.txt` |
| Clients en `VERIFY_IDENTITY` | Les scripts de démonstration (`demo_manager.sh`, `test_salaires.sh`) utilisent `--ssl-mode=VERIFY_IDENTITY` avec la CA du projet (le SAN contient `db`). Connexion refusée avec un nom absent du SAN. | `18b_tls_actif.txt`, `46_*`, `46b_*`, `47_*` |
| Un compte exigeant un certificat client | `tls_client_camara` avec `REQUIRE SUBJECT '/CN=rh-client'` : refusé avec le mot de passe seul, accepté avec le certificat et la clé du client. | `18c_compte_x509.txt` |
| Keyring | `component_keyring_file` chargé au démarrage ; fichier du keyring dans `keyring_data/` (mode 700, propriétaire UID 999). | `17a_chiffrement_repos.txt`, `35_au_repos.txt` |
| Tables sensibles et schéma chiffrés par défaut | `default_table_encryption=ON` et `table_encryption_privilege_check=ON` ; les 6 tables de `rh_camara` sont en `ENCRYPTION='Y'`. | `17b_preuve_ibd.txt`, `35b_au_repos.txt` |
| Redo, undo et binlog chiffrés | `innodb_redo_log_encrypt=ON`, `innodb_undo_log_encrypt=ON`, `binlog_encryption=ON`. | `17b_preuve_ibd.txt` |
| Preuve que la donnée n'apparaît plus en clair dans le `.ibd` | `scripts/verifier_ibd_chiffre.sh` : 0 occurrence dans `employes.ibd` et `salaires.ibd`. Contre-épreuve : une table témoin non chiffrée contient 70 occurrences du même nom. | `17b_preuve_ibd.txt`, `36_ibd.txt` |

### Chiffrement de colonne (contrainte D)

- `block_encryption_mode = aes-256-cbc` est fixé dans `conf/mysql.cnf` : le défaut de MySQL est `aes-128-ecb` (voir `14_etat_avant_chiffrement.txt` et `15a_mode_aes.txt`).
- Le tablespace `mysql` est aussi chiffré (`ALTER TABLESPACE mysql ENCRYPTION='Y'`, voir `35_au_repos.txt` puis `35b_au_repos.txt`).
- `sql/20_chiffrement_salaires.sql` crée `fn_chiffrer` et `fn_dechiffrer` (propriétaire `rh_crypto_owner`) : AES-256-CBC, IV de 16 octets tiré par `RANDOM_BYTES(16)` et placé devant le chiffré. La clé de 32 octets est exigée par les fonctions (erreur sinon).
- Le script ajoute trois colonnes `*_chiffre`, chiffre les 14 400 lignes, **contrôle que chaque ligne se déchiffre à l'identique**, puis supprime les colonnes en clair. `primes` et `net_a_payer` sont chiffrés aussi : `net_a_payer = (brut + primes) × 0,78`, donc le laisser en clair révélerait le salaire.
- `sql/21_routines_salaires.sql` crée `sp_ecrire_salaire` et `sp_lire_salaires`, seul chemin d'accès. La clé est un paramètre : elle n'est jamais stockée dans la base. Les droits directs de `role_paie` et de `role_drh` sur `salaires` sont retirés.
- Résultats : lecture par la paie avec la bonne clé (12 mois), erreur 1644 avec une mauvaise clé, `SELECT` direct refusé (1142), appel de la procédure refusé au DRH, au gestionnaire et au manager (1370). Les 12 mois d'un même employé donnent 12 chiffrés différents.

## 7. Sauvegarde et restauration (bloc 3.9)

- **`scripts/sauvegarde.sh`** : `FLUSH BINARY LOGS`, puis `mysqldump --single-transaction --routines --triggers --events --source-data=2`, copie des binlogs et du keyring. Chaque fichier est chiffré avec OpenSSL AES-256-CBC (PBKDF2, 600 000 itérations, sel) et listé dans `SHA256SUMS`. La passphrase est `secrets/backup_passphrase.txt` (générée si absente, mode 600). Chaque sauvegarde est dans `backups/<horodatage>/` (mode 700). Preuve : `38_backups.txt`.
- **Keyring stocké séparément** : après la sauvegarde, déplacez `keyring.enc` hors du projet (`mv backups/<horodatage>/keyring.enc ~/keyring_hors_projet/`). Avant une restauration, remettez-le dans le dossier de la sauvegarde : `restauration.sh` en a besoin pour la vérification SHA-256 et pour restaurer le chiffrement des tablespaces.
- **`scripts/restauration.sh`** : vérification SHA-256, déchiffrement du keyring, démarrage d'un conteneur MySQL 8.4 vierge (`rh-restore-test`), restauration du dump déchiffré à la volée, contrôle des comptages (1 200 employés, 14 400 salaires), vérification des IV distincts et des options de chiffrement des tables. Le conteneur de test est supprimé à la fin.
- **Objectifs fixés** : RTO ≤ 300 s (5 min) ; RPO ≤ 15 min.
- **RTO mesuré** : 7 s (`preuves/19b_restauration_vierge.txt`, restauration en conteneur vierge, sans keyring). Le script `restauration.sh` actuel (avec keyring) n'a pas de sortie complète enregistrée : `39_restauration.txt` s'arrête à l'étape 3.
- **RPO** : l'objectif de 15 min n'est pas démontré (limite n° 1).

## 8. Conformité et audit (bloc 3.10)

- **Matrice exigence / mesure / preuve** : 11 lignes rattachées à la loi 09-08 et au sujet, dans `conformite/matrice_conformite.md` (section 1).
- **Écarts restants et plan de remédiation priorisé** : sections 2 et 3 du même fichier, et section 10 de ce README.
- **Audit « avant »** : `conformite/audit_avant.csv`, sortie de `audit-mysql.sh` du kit sur un MySQL 8.4.13 vierge (image officielle, configuration d'usine) : **19 PASS, 11 FAIL, 9 WARN**. FAIL : D04 (root accessible hors local), A03 à A05 (pas de `validate_password`), C01 (TLS non imposé), C04 (pas de keyring), C06 (pas de chiffrement par défaut), C07 à C09 (redo, undo, binlog non chiffrés), H05 (GTID).
- **Mesures qui corrigent ces FAIL** : D04 (`04_root_localhost.sql`), A03 à A05 (`02_auth.sql`), C01 (`require_secure_transport`), C04 et C06 à C09 (keyring, chiffrement par défaut, redo, undo, binlog). H05 relève du bonus 3.7 (réplication), non traité.
- **Audit « après »** : la sortie de l'outil du kit sur `rh-db` n'a pas pu être capturée (connexion refusée depuis le client avec le compte d'audit ; voir limite n° 7). Le relevé manuel `conformite/rapport_audit_apres.txt` (version 8.4.13, `skip_name_resolve`, `local_infile`, `general_log`, `slow_query_log`, `require_secure_transport`, `tls_version`, `default_table_encryption`, `binlog_encryption`, nombre de comptes) le remplace partiellement, sans être la sortie de l'outil.
- **États « avant » conservés** : `03_comptes_avant.txt`, `14_etat_avant_chiffrement.txt`, `18a_etat_tls.txt`.

## 9. Justification des choix

| Choix | Pourquoi |
|---|---|
| Vues `DEFINER` filtrées sur `USER()` | Un seul objet sert tous les managers ; le manager n'a aucun droit sur `employes`. |
| Propriétaire des vues verrouillé | Le compte qui exécute les vues ne peut pas servir à se connecter. |
| AES-256-CBC, IV aléatoire par valeur | Contrainte D : deux salaires identiques donnent deux chiffrés différents ; l'IV est stocké devant le chiffré, donc rien d'autre à conserver. |
| Chiffrer aussi `primes` et `net_a_payer` | Le net se déduit du brut et des primes : le laisser en clair annulerait le chiffrement. |
| Clé hors base, passée en paramètre | Une copie de la base, ou un administrateur de base, ne suffit pas à lire les salaires. |
| Accès aux salaires par procédures uniquement | La paie n'a aucun droit direct sur la table ; chaque appel exige la clé. |
| Droits par colonne pour le gestionnaire RH | Minimisation des données (loi 09-08) : il ne modifie ni le CIN, ni le compte MySQL. |
| Keyring dans un dossier séparé | Les clés ne sont pas stockées à côté des données chiffrées. |
| TLS 1.2/1.3 imposé, SAN, certificat client | Empêche l'écoute du réseau et l'usurpation du serveur ; le certificat client authentifie la machine. |
| Politique STRONG, expiration, verrouillage | Données personnelles de salariés : réduire le risque de compromission des comptes. |
| Sauvegarde chiffrée avec SHA-256, keyring à part | Une sauvegarde en clair contiendrait les données des salariés ; le keyring séparé évite qu'une copie suffise à tout déchiffrer. |
| Aucun port publié, réseau privé | Réduit la surface d'attaque ; la base n'est atteinte que par le poste client. |

## 10. Limites connues et plan de remédiation

Par ordre de priorité :

1. **RPO non démontré.** Les binlogs ne sont copiés qu'à chaque exécution de `sauvegarde.sh`, qui n'est pas planifiée. Remédiation : copie continue des binlogs et sauvegarde planifiée.
2. **La restauration ne recrée pas les comptes, rôles et droits** (la sauvegarde ne contient que `rh_camara`). Il faut rejouer les étapes 6 à 9 de la section 2.
3. **Les fichiers `sql/` ne reproduisent pas exactement l'état final** : les droits par colonne du gestionnaire RH, les droits finaux de `rh_view_owner`, les comptes techniques (`rh_crypto_owner`, `rh_camara_app`, `tls_client_camara`) et le chiffrement du tablespace `mysql` sont documentés dans ce README et les preuves, mais pas tous regroupés dans un script. Remédiation : scripts `sql/06_*` et `sql/07_*`, puis test à blanc avec `docker compose down -v`.
4. **`rh_view_owner` a un `SELECT` sur les tables `employes` et `absences` entières** (`11d_isolation_vue.txt`). Les droits par colonne produisaient l'erreur 1143 sur la jointure des vues ; la cause n'a pas été identifiée (`11c` à `11f`). Atténuation : compte verrouillé, vues limitées aux colonnes utiles.
5. **Secrets et keyring sur la même machine, sans copie hors site.** Passphrase de sauvegarde, clé AES, clé privée de la CA et keyring sont sur l'hôte ; le déplacement de `keyring.enc` est manuel. Remédiation : gestionnaire de secrets ou copie hors site.
6. **Le dossier `certs/` est monté en entier dans `db` et `client`** : la clé privée du serveur et celle de la CA sont visibles des deux conteneurs. Remédiation : monter chaque fichier séparément, seulement ceux dont le service a besoin.
7. **Audit du kit « après » non capturé** (voir section 8). Remédiation : l'exécuter depuis le conteneur `db` avec `root` local, ou avec un compte d'audit nominatif dont le mot de passe est connu.
8. **La clé AES des salaires transite dans le texte des appels `CALL`** : protégée sur le réseau par TLS, mais visible dans `performance_schema` et les journaux lents pour un administrateur. Remédiation : clé tenue par l'application (KMS), jamais dans une requête SQL.
9. **Pas de traçabilité des accès ni des modifications sur les salaires** : le trigger d'audit relève du bonus 3.5, non traité.
10. **`role_drh` a `INSERT` et `UPDATE` sur des tables entières**, sans restriction par colonne.
11. **Certificats valables 365 jours**, sans renouvellement automatique.
12. **Sauvegarde exécutée avec le compte `root`** (mot de passe lu dans le conteneur) ; le compte `backup_camara` et son rôle existent mais ne sont pas utilisés par le script.
13. **`rh_camara_app` n'expire pas** : choix assumé pour ne pas couper l'application, compensé par la rotation à double mot de passe.

## 11. Bonus non traités

Les blocs 3.5 (requêtes préparées, index, trigger d'audit), 3.7 (réplication et bascule) et 3.8 (ProxySQL) ne sont pas traités, par manque de temps. Il n'y a donc ni trigger d'audit, ni réplica, ni répartition de charge.

## 12. Arborescence

```
CAMARA_Sara_BDD/
├── README.md
├── docker-compose.yml
├── conf/          mysql.cnf, mysqld.my, component_keyring_file.cnf
├── certs/         certificats publics seulement (ca.pem, server-cert.pem, client-cert.pem, server-san.cnf)
├── sql/           01_D_rh, 02_auth, 03_roles, 04_root_localhost, 05_admin_nominatif,
│                  20_chiffrement_salaires, 20b_reprise_migration, 21_routines_salaires
├── scripts/       generer_tls, activer_keyring, creer_comptes, rotation_mdp_app, demo_manager,
│                  test_salaires, verifier_ibd_chiffre, sauvegarde, restauration
├── secrets/       *.example uniquement
├── preuves/       sorties de commandes
├── conformite/    matrice_conformite.md, rapport_audit_apres.txt
└── presentation.pdf
```

Aucune clé privée, aucun mot de passe réel, aucun fichier keyring ni sauvegarde n'est inclus dans l'archive : `certs/ca-key.pem`, `certs/*-key.pem`, `keyring_data/`, `secrets/*.txt`, `secrets/comptes/` et `backups/` sont exclus.

## 13. Ressources externes citées

- Documentation MySQL 8.4 : composant `validate_password`, gestion des mots de passe (double mot de passe, verrouillage), chiffrement InnoDB et keyring, connexions chiffrées, fonctions `AES_ENCRYPT` et `RANDOM_BYTES`, sécurité des objets stockés (`DEFINER`). https://dev.mysql.com/doc/refman/8.4/en/
- Image Docker officielle `mysql` (variables `_FILE`, secrets). https://hub.docker.com/_/mysql
- OpenSSL : `req`, `x509`, `enc` (PBKDF2). https://docs.openssl.org/
- Loi 09-08 relative à la protection des personnes physiques à l'égard du traitement des données à caractère personnel.
- Kit de TP du cours (labs et corrigés) fourni par l'enseignant.
- Assistant IA (Claude, Anthropic) : relecture du livrable, explication d'erreurs et vérification de la cohérence entre le README, les preuves et la présentation. Les choix techniques, les commandes exécutées et les preuves sont les miens.
