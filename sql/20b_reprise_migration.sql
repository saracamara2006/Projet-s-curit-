USE rh_camara;
SET SESSION block_encryption_mode = 'aes-256-cbc';
SET @k := UNHEX('@@CLE@@');

UPDATE salaires
   SET salaire_brut_chiffre = fn_chiffrer(salaire_brut, @k),
       primes_chiffre       = fn_chiffrer(primes, @k),
       net_a_payer_chiffre  = fn_chiffrer(net_a_payer, @k);

DROP PROCEDURE IF EXISTS sp_tmp_verifier_migration;
DELIMITER $$
CREATE PROCEDURE sp_tmp_verifier_migration(IN p_cle VARBINARY(32))
BEGIN
  DECLARE v_nulls INT; DECLARE v_ecarts INT;
  SELECT COUNT(*) INTO v_nulls FROM salaires
   WHERE salaire_brut_chiffre IS NULL OR primes_chiffre IS NULL OR net_a_payer_chiffre IS NULL;
  SELECT COUNT(*) INTO v_ecarts FROM salaires
   WHERE fn_dechiffrer(salaire_brut_chiffre, p_cle) <> salaire_brut
      OR fn_dechiffrer(primes_chiffre, p_cle)       <> primes
      OR fn_dechiffrer(net_a_payer_chiffre, p_cle)  <> net_a_payer;
  IF v_nulls > 0 OR v_ecarts > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Migration incoherente : suppression du clair annulee';
  END IF;
END$$
DELIMITER ;
CALL sp_tmp_verifier_migration(@k);
DROP PROCEDURE sp_tmp_verifier_migration;
SELECT 'CONTROLE OK : chaque ligne se dechiffre a l identique' AS verification;

ALTER TABLE salaires
  DROP COLUMN salaire_brut, DROP COLUMN primes, DROP COLUMN net_a_payer,
  MODIFY salaire_brut_chiffre VARBINARY(64) NOT NULL,
  MODIFY primes_chiffre       VARBINARY(64) NOT NULL,
  MODIFY net_a_payer_chiffre  VARBINARY(64) NOT NULL;
SET @k := NULL;

SHOW COLUMNS FROM salaires;
SELECT mois, HEX(LEFT(salaire_brut_chiffre,16)) AS iv_hex, HEX(SUBSTRING(salaire_brut_chiffre,17)) AS chiffre_hex
  FROM salaires WHERE employe_id = 1 ORDER BY mois;
SELECT COUNT(*) AS mois, COUNT(DISTINCT salaire_brut_chiffre) AS chiffres_distincts FROM salaires WHERE employe_id = 1;
