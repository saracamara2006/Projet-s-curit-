CREATE ROLE IF NOT EXISTS 'role_drh','role_gestionnaire_rh','role_paie','role_manager','role_auditeur_rh','role_sauvegarde','role_supervision';

GRANT SELECT, INSERT, UPDATE ON rh_camara.employes TO 'role_drh';
GRANT SELECT, INSERT, UPDATE ON rh_camara.departements TO 'role_drh';
GRANT SELECT, INSERT, UPDATE ON rh_camara.contrats TO 'role_drh';
GRANT SELECT, INSERT, UPDATE ON rh_camara.absences TO 'role_drh';
GRANT SELECT, INSERT, UPDATE ON rh_camara.evaluations TO 'role_drh';
GRANT SELECT ON rh_camara.salaires TO 'role_drh';

GRANT SELECT, INSERT, UPDATE ON rh_camara.employes TO 'role_gestionnaire_rh';
GRANT SELECT ON rh_camara.departements TO 'role_gestionnaire_rh';
GRANT SELECT, INSERT, UPDATE ON rh_camara.contrats TO 'role_gestionnaire_rh';
GRANT SELECT, INSERT, UPDATE ON rh_camara.absences TO 'role_gestionnaire_rh';

GRANT SELECT (id, matricule, nom, prenom, departement_id) ON rh_camara.employes TO 'role_paie';
GRANT SELECT, INSERT, UPDATE ON rh_camara.salaires TO 'role_paie';

GRANT SELECT ON rh_camara.departements TO 'role_auditeur_rh';
GRANT SELECT ON rh_camara.contrats TO 'role_auditeur_rh';
GRANT SELECT ON rh_camara.absences TO 'role_auditeur_rh';

GRANT SELECT, SHOW VIEW, LOCK TABLES ON rh_camara.* TO 'role_sauvegarde';
GRANT RELOAD, PROCESS, REPLICATION CLIENT, BACKUP_ADMIN ON *.* TO 'role_sauvegarde';

GRANT PROCESS, REPLICATION CLIENT ON *.* TO 'role_supervision';
GRANT SELECT ON performance_schema.* TO 'role_supervision';
GRANT SELECT ON sys.* TO 'role_supervision';

CREATE USER IF NOT EXISTS 'rh_view_owner'@'%' IDENTIFIED WITH caching_sha2_password BY RANDOM PASSWORD ACCOUNT LOCK;
GRANT SELECT (id, matricule, nom, prenom, email_pro, poste, departement_id, date_embauche, manager_id, compte_mysql) ON rh_camara.employes TO 'rh_view_owner'@'%';
GRANT SELECT (id, employe_id, type_absence, date_debut, date_fin, statut) ON rh_camara.absences TO 'rh_view_owner'@'%';

CREATE OR REPLACE DEFINER='rh_view_owner'@'%' SQL SECURITY DEFINER VIEW rh_camara.v_mon_equipe AS
SELECT e.id, e.matricule, e.nom, e.prenom, e.email_pro, e.poste, e.departement_id, e.date_embauche
FROM rh_camara.employes e
JOIN rh_camara.employes m ON m.id = e.manager_id
WHERE m.compte_mysql = SUBSTRING_INDEX(USER(), '@', 1);

CREATE OR REPLACE DEFINER='rh_view_owner'@'%' SQL SECURITY DEFINER VIEW rh_camara.v_absences_equipe AS
SELECT a.id, a.employe_id, a.type_absence, a.date_debut, a.date_fin, a.statut
FROM rh_camara.absences a
JOIN rh_camara.employes e ON e.id = a.employe_id
JOIN rh_camara.employes m ON m.id = e.manager_id
WHERE m.compte_mysql = SUBSTRING_INDEX(USER(), '@', 1);

GRANT SELECT ON rh_camara.v_mon_equipe TO 'role_manager';
GRANT SELECT ON rh_camara.v_absences_equipe TO 'role_manager';
