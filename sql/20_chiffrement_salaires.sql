USE rh_camara;
SET SESSION block_encryption_mode = 'aes-256-cbc';

DROP FUNCTION IF EXISTS fn_chiffrer;
DROP FUNCTION IF EXISTS fn_dechiffrer;

DELIMITER $$
CREATE DEFINER = 'rh_crypto_owner'@'%' FUNCTION fn_chiffrer(p_valeur DECIMAL(10,2), p_cle VARBINARY(32))
  RETURNS VARBINARY(64) NOT DETERMINISTIC NO SQL SQL SECURITY DEFINER
BEGIN
  DECLARE v_iv VARBINARY(16);
  IF p_cle IS NULL OR LENGTH(p_cle) <> 32 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cle AES-256 invalide : 32 octets attendus';
  END IF;
  SET v_iv = RANDOM_BYTES(16);
  RETURN CONCAT(v_iv, AES_ENCRYPT(CAST(p_valeur AS CHAR), p_cle, v_iv));
END$$

CREATE DEFINER = 'rh_crypto_owner'@'%' FUNCTION fn_dechiffrer(p_blob VARBINARY(64), p_cle VARBINARY(32))
  RETURNS DECIMAL(10,2) DETERMINISTIC NO SQL SQL SECURITY DEFINER
BEGIN
  DECLARE v_clair VARBINARY(32);
  IF p_blob IS NULL THEN RETURN NULL; END IF;
  IF p_cle IS NULL OR LENGTH(p_cle) <> 32 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cle AES-256 invalide : 32 octets attendus';
  END IF;
  SET v_clair = AES_DECRYPT(SUBSTRING(p_blob, 17), p_cle, SUBSTRING(p_blob, 1, 16));
  IF v_clair IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Dechiffrement impossible : mauvaise cle ou donnee alteree';
  END IF;
  RETURN CAST(v_clair AS DECIMAL(10,2));
END$$
DELIMITER ;
GRANT EXECUTE ON FUNCTION rh_camara.fn_chiffrer TO 'rh_crypto_owner'@'%';
GRANT EXECUTE ON FUNCTION rh_camara.fn_dechiffrer TO 'rh_crypto_owner'@'%';

ALTER TABLE salaires
  ADD COLUMN salaire_brut_chiffre VARBINARY(64) NULL AFTER mois,
  ADD COLUMN primes_chiffre       VARBINARY(64) NULL AFTER salaire_brut_chiffre,
  ADD COLUMN net_a_payer_chiffre  VARBINARY(64) NULL AFTER primes_chiffre;

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
