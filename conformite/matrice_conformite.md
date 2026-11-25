# Conformité et audit — Variante D (Ressources humaines / rh_camara)

## 1. Matrice Exigence / Mesure / Preuve (Loi 09-08 & Sujet)

| # | Cadre / Exigence | Mesure mise en place | Preuve |
|---|---|---|---|
| 1 | Loi 09-08 (confidentialité & sécurité des données personnelles RH) | Base `rh_camara` isolée, durcissement serveur (`skip_name_resolve`, `local_infile=OFF`, `sql_mode` strict, `general_log=OFF`, journaux d'erreurs et requêtes lentes actifs) | `conf/mysql.cnf`, `conformite/rapport_audit_apres.txt` |
| 2 | Loi 09-08 (contrôle d'accès / principe du moindre privilège) | RBAC avec rôles dédiés (`role_drh`, `role_gestionnaire_rh`, `role_paie`, `role_auditeur_rh`, `role_sauvegarde`, `role_supervision`, `role_manager`), sans `FILE` ni `GRANT OPTION` sur les comptes applicatifs | `preuves/12b_show_grants_using.txt`, `preuves/12c_nettoyage_et_durcissement_roles.txt` |
| 3 | Variante D & Loi 09-08 (manager limité à son équipe, jamais les salaires) | Vues filtrées (`v_mon_equipe`, `v_absences_equipe`) en `SQL SECURITY DEFINER` avec propriétaire verrouillé (`rh_view_owner`) et refus d'accès direct aux salaires/employés | `preuves/13_demo_manager.txt`, `preuves/12d_test_gestionnaire.txt` |
| 4 | Variante D & Loi 09-08 (chiffrement colonne AES-256-CBC + IV aléatoire) | Colonnes `*_chiffre` en `VARBINARY(64)` via `aes-256-cbc` avec IV aléatoire (`RANDOM_BYTES(16)`), suppression des colonnes en clair, accès par procédures (`sp_ecrire_salaire`, `sp_lire_salaires`) | `preuves/15b_migration_chiffrement.txt`, `preuves/16b_test_salaires.txt` |
| 5 | Loi 09-08 & Bloc 3.6 (chiffrement au repos) | Composant `component_keyring_file` actif, `ENCRYPTION='Y'` sur les tables de `rh_camara`, chiffrement redo/undo/binlog et tables par défaut activés | `preuves/17a_chiffrement_repos.txt` |
| 6 | Loi 09-08 & Bloc 3.6 (chiffrement en transit) | `require_secure_transport=ON`, `TLSv1.2,TLSv1.3`, certificats avec SAN, vérification `VERIFY_IDENTITY` côté client | `preuves/18b_tls_actif.txt` |
| 7 | Bloc 3.6 (authentification forte par certificat client) | Compte `tls_client_camara@172.31.77.20` exigeant un certificat client (`REQUIRE SUBJECT '/CN=rh-client'`), refus sans certificat client | `preuves/18c_compte_x509.txt` |
| 8 | Loi 09-08 (intégrité & restriction de modification des données) | Droits par colonne sur `employes` pour le gestionnaire RH (`compte_mysql` et `cin` refusés en modification) | `preuves/12d_test_gestionnaire.txt` |
| 9 | Loi 09-08 & Bloc 3.9 (disponibilité et sauvegardes) | Script `scripts/sauvegarde.sh` (dump complet, binlogs, copie séparée du keyring) | `preuves/19a_sauvegarde.txt` |
| 10 | Bloc 3.9 (continuité d'activité, RPO et RTO) | Test de restauration sur conteneur MySQL vierge avec mesure du RTO et définition du RPO cible | `preuves/19b_restauration_vierge.txt` |
| 11 | Bloc 3.10 (audit de sécurité) | Relevé des variables de sécurité et du nombre de comptes (`rapport_audit_apres.txt`) ; l'outil d'audit du kit n'a pas été exécuté sur l'état initial | `conformite/rapport_audit_apres.txt` |

## 2. Écarts restants
* **RPO** de 15 min non démontré : les binlogs ne sont copiés qu'à chaque sauvegarde, qui n'est pas planifiée.
* **La restauration ne recrée pas** les comptes, rôles et droits.
* **Secrets et keyring** sur la même machine, sans copie hors site.
* **`role_drh`** a `INSERT` et `UPDATE` sur des tables entières.
* **Audit « avant » durcissement** non capturé ; le rapport « après » est un relevé manuel.
* **Certificats** valables 365 jours, sans renouvellement automatique.
* **Sauvegarde** exécutée avec `root` ; `backup_camara` n'est pas utilisé.

## 3. Plan de remédiation priorisé
1. Planifier la sauvegarde et copier les binlogs en continu pour viser un RPO de 15 min.
2. Placer secrets et keyring hors de la machine ; copie hors site.
3. Restreindre par colonnes les droits de `role_drh` ; utiliser `backup_camara` dans le script de sauvegarde.
4. Exécuter l'outil d'audit du kit avant et après durcissement.
5. Automatiser le renouvellement des certificats.
