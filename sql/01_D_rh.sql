-- =============================================================================
--  Examen BDD B3 Cybersécurité | Maroc Ynov Campus | Hamza ESSAD
--  Script de départ : variante D, Ressources humaines
--  Données 100 % fictives, générées par le script. Aucune donnée réelle.
--
--  Utilisation (remplacez <nom> par votre nom, en minuscules) :
--    CREATE DATABASE rh_<nom> CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
--    mysql rh_<nom> < D_rh.sql
--
--  Les salaires sont livrés EN CLAIR : leur chiffrement au niveau colonne fait
--  partie de votre travail (contrainte de la variante D).
--  La colonne employes.compte_mysql contient le nom du compte MySQL des
--  managers (mgr_dsi, mgr_fin...). Ces comptes ne sont PAS créés par ce
--  script : c'est à vous de les créer et de les relier à la vue filtrée.
--
--  Le script ne crée volontairement AUCUNE mesure de sécurité : pas de rôle,
--  pas de chiffrement, pas de trigger, pas d'index en dehors des clés.
--  C'est à vous de sécuriser cette base. Vous pouvez ajouter des colonnes ou
--  des tables si votre sécurisation l'exige, en le documentant dans le README.
--  Le script est rejouable : il supprime puis recrée ses tables.
-- =============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS evaluations, absences, salaires, contrats, employes, departements;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE departements (
  id          SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code        VARCHAR(10)  NOT NULL UNIQUE,
  libelle     VARCHAR(80)  NOT NULL,
  manager_id  INT UNSIGNED NULL
) ENGINE = InnoDB;

CREATE TABLE employes (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  matricule       VARCHAR(12)  NOT NULL UNIQUE,
  cin             VARCHAR(10)  NOT NULL UNIQUE,
  nom             VARCHAR(60)  NOT NULL,
  prenom          VARCHAR(60)  NOT NULL,
  date_naissance  DATE         NOT NULL,
  email_pro       VARCHAR(120) NOT NULL UNIQUE,
  telephone       VARCHAR(15)  NOT NULL,
  adresse         VARCHAR(160) NOT NULL,
  departement_id  SMALLINT UNSIGNED NOT NULL,
  manager_id      INT UNSIGNED NULL,
  poste           VARCHAR(80)  NOT NULL,
  date_embauche   DATE         NOT NULL,
  compte_mysql    VARCHAR(32)  NULL UNIQUE,
  CONSTRAINT fk_employe_dep     FOREIGN KEY (departement_id) REFERENCES departements (id),
  CONSTRAINT fk_employe_manager FOREIGN KEY (manager_id)     REFERENCES employes (id)
) ENGINE = InnoDB;

CREATE TABLE contrats (
  id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  employe_id     INT UNSIGNED NOT NULL,
  type_contrat   ENUM('CDI','CDD','Stage','Intérim') NOT NULL,
  date_debut     DATE         NOT NULL,
  date_fin       DATE         NULL,
  temps_travail  ENUM('plein','partiel') NOT NULL,
  CONSTRAINT fk_contrat_employe FOREIGN KEY (employe_id) REFERENCES employes (id)
) ENGINE = InnoDB;

CREATE TABLE salaires (
  id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  employe_id    INT UNSIGNED  NOT NULL,
  mois          DATE          NOT NULL,      -- premier jour du mois payé
  salaire_brut  DECIMAL(10,2) NOT NULL,      -- en clair : à chiffrer (contrainte de la variante)
  primes        DECIMAL(10,2) NOT NULL,
  net_a_payer   DECIMAL(10,2) NOT NULL,
  UNIQUE KEY uq_salaire_mois (employe_id, mois),
  CONSTRAINT fk_salaire_employe FOREIGN KEY (employe_id) REFERENCES employes (id)
) ENGINE = InnoDB;

CREATE TABLE absences (
  id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  employe_id   INT UNSIGNED NOT NULL,
  type_absence ENUM('conges','maladie','formation','sans_solde','evenement_familial') NOT NULL,
  date_debut   DATE         NOT NULL,
  date_fin     DATE         NOT NULL,
  statut       ENUM('demandee','validee','refusee') NOT NULL,
  CONSTRAINT fk_absence_employe FOREIGN KEY (employe_id) REFERENCES employes (id)
) ENGINE = InnoDB;

CREATE TABLE evaluations (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  employe_id      INT UNSIGNED NOT NULL,
  evaluateur_id   INT UNSIGNED NOT NULL,
  annee           SMALLINT UNSIGNED NOT NULL,
  note            TINYINT UNSIGNED NOT NULL,   -- 1 à 5
  commentaire     VARCHAR(255) NOT NULL,
  UNIQUE KEY uq_eval_annee (employe_id, annee),
  CONSTRAINT fk_eval_employe    FOREIGN KEY (employe_id)    REFERENCES employes (id),
  CONSTRAINT fk_eval_evaluateur FOREIGN KEY (evaluateur_id) REFERENCES employes (id)
) ENGINE = InnoDB;

INSERT INTO departements (code, libelle) VALUES
  ('DSI', 'Direction des systèmes d''information'),
  ('FIN', 'Finance et comptabilité'),
  ('RH',  'Ressources humaines'),
  ('COM', 'Commercial'),
  ('MKT', 'Marketing'),
  ('LOG', 'Logistique'),
  ('JUR', 'Juridique'),
  ('PROD', 'Production');

-- Table auxiliaire de 1 à 10 000 (supprimée en fin de script)
DROP TABLE IF EXISTS _seq;
CREATE TABLE _seq (n INT UNSIGNED PRIMARY KEY);
INSERT INTO _seq (n)
SELECT 1 + a.d + 10 * b.d + 100 * c.d + 1000 * e.d
FROM (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
CROSS JOIN (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
CROSS JOIN (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) c
CROSS JOIN (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) e;

-- 1 200 employés : les 8 premiers sont les managers des 8 départements
INSERT INTO employes (matricule, cin, nom, prenom, date_naissance, email_pro, telephone, adresse,
                      departement_id, manager_id, poste, date_embauche, compte_mysql)
SELECT CONCAT('EMP-', LPAD(n, 5, '0')),
       CONCAT(ELT(1 + n % 8, 'A', 'B', 'BE', 'BK', 'C', 'CD', 'D', 'EE'), 500000 + n * 13),
       ELT(1 + (n * 7) % 20, 'Alaoui', 'Bennani', 'El Idrissi', 'Tazi', 'Berrada', 'Chraibi', 'Benjelloun', 'El Fassi', 'Amrani', 'Ouazzani',
                         'Lahlou', 'Kettani', 'Sebti', 'Naciri', 'Bouzidi', 'Haddad', 'Mansouri', 'Ziani', 'Rami', 'Saidi'),
       ELT(1 + (n DIV 20 + n * 11) % 20, 'Youssef', 'Salma', 'Mehdi', 'Imane', 'Omar', 'Khadija', 'Amine', 'Sara', 'Hamza', 'Nadia',
                         'Karim', 'Meryem', 'Anas', 'Ghita', 'Reda', 'Hiba', 'Yassine', 'Zineb', 'Adam', 'Lina'),
       DATE '1965-01-01' + INTERVAL ((n * 2711) % 13000) DAY,
       CONCAT('employe', n, '@entreprise.example'),
       CONCAT('06', LPAD((n * 8023021 + 41) % 100000000, 8, '0')),
       CONCAT(1 + n % 120, ', rue ', ELT(1 + n % 4, 'Abou Bakr', 'Al Khalil', 'Ibn Batouta', 'Al Mansour')),
       IF(n <= 8, n, 1 + n % 8),
       NULL,
       IF(n <= 8, 'Manager',
          ELT(1 + (n * 3) % 6, 'Analyste', 'Chargé de mission', 'Technicien', 'Assistant', 'Ingénieur', 'Consultant')),
       DATE '2010-01-01' + INTERVAL ((n * 4099) % 5400) DAY,
       NULL
FROM _seq WHERE n <= 1200;

UPDATE employes e JOIN departements d ON d.id = e.departement_id
SET e.manager_id = d.id
WHERE e.id > 8;

UPDATE employes e JOIN departements d ON d.id = e.id
SET e.compte_mysql = CONCAT('mgr_', LOWER(d.code));

UPDATE departements SET manager_id = id;
ALTER TABLE departements
  ADD CONSTRAINT fk_dep_manager FOREIGN KEY (manager_id) REFERENCES employes (id);

-- Un contrat par employé
INSERT INTO contrats (employe_id, type_contrat, date_debut, date_fin, temps_travail)
SELECT e.id,
       IF(e.id <= 8, 'CDI', ELT(1 + e.id % 10, 'CDI', 'CDI', 'CDI', 'CDI', 'CDI', 'CDI', 'CDD', 'CDD', 'Stage', 'Intérim')),
       e.date_embauche,
       IF(e.id > 8 AND e.id % 10 >= 6, e.date_embauche + INTERVAL 12 MONTH, NULL),
       IF(e.id % 15 = 0, 'partiel', 'plein')
FROM employes e;

-- 12 mois de salaires (2025-10 à 2026-09) par employé
INSERT INTO salaires (employe_id, mois, salaire_brut, primes, net_a_payer)
SELECT e.id, m.mois, b.brut, b.primes, ROUND((b.brut + b.primes) * 0.78, 2)
FROM employes e
JOIN (SELECT DATE '2025-10-01' + INTERVAL k MONTH AS mois
      FROM (SELECT 0 k UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5
            UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11) t) m
JOIN (SELECT id,
             IF(id <= 8, 32000.00, 6000.00 + (id * 7919) % 22000) AS brut,
             IF(id % 4 = 0, 1500.00, 0.00) AS primes
      FROM employes) b ON b.id = e.id;

-- 3 000 absences
INSERT INTO absences (employe_id, type_absence, date_debut, date_fin, statut)
SELECT 1 + (n * 7) % 1200,
       ELT(1 + n % 8, 'conges', 'conges', 'conges', 'maladie', 'formation', 'conges', 'sans_solde', 'evenement_familial'),
       DATE '2025-01-02' + INTERVAL ((n * 31) % 600) DAY,
       DATE '2025-01-02' + INTERVAL ((n * 31) % 600 + n % 10) DAY,
       ELT(1 + n % 6, 'validee', 'validee', 'validee', 'validee', 'demandee', 'refusee')
FROM _seq WHERE n <= 3000;

-- Évaluations annuelles 2024 et 2025, faites par le manager
INSERT INTO evaluations (employe_id, evaluateur_id, annee, note, commentaire)
SELECT e.id, e.manager_id, y.annee, 1 + (e.id * 3 + y.annee) % 5,
       ELT(1 + (e.id + y.annee) % 5, 'Objectifs partiellement atteints', 'Bonne progression sur l''année',
           'Objectifs atteints', 'Très bon travail d''équipe', 'Résultats remarquables')
FROM employes e
JOIN (SELECT 2024 annee UNION ALL SELECT 2025) y
WHERE e.manager_id IS NOT NULL;

DROP TABLE _seq;

SELECT 'departements' AS table_name, COUNT(*) AS lignes FROM departements
UNION ALL SELECT 'employes', COUNT(*) FROM employes
UNION ALL SELECT 'contrats', COUNT(*) FROM contrats
UNION ALL SELECT 'salaires', COUNT(*) FROM salaires
UNION ALL SELECT 'absences', COUNT(*) FROM absences
UNION ALL SELECT 'evaluations', COUNT(*) FROM evaluations;
