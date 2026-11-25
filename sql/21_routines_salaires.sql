USE rh_camara;
DROP PROCEDURE IF EXISTS sp_ecrire_salaire;
DROP PROCEDURE IF EXISTS sp_lire_salaires;
DELIMITER $$
CREATE DEFINER = 'rh_crypto_owner'@'%' PROCEDURE sp_ecrire_salaire(
    IN p_employe_id INT UNSIGNED, IN p_mois DATE,
    IN p_brut DECIMAL(10,2), IN p_primes DECIMAL(10,2), IN p_cle VARBINARY(32))
  MODIFIES SQL DATA SQL SECURITY DEFINER
BEGIN
  DECLARE v_net DECIMAL(10,2);
  IF p_brut < 0 OR p_primes < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Montants negatifs interdits';
  END IF;
  IF DAY(p_mois) <> 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Le mois doit etre le premier jour du mois';
  END IF;
  SET v_net = ROUND((p_brut + p_primes) * 0.78, 2);
  INSERT INTO salaires (employe_id, mois, salaire_brut_chiffre, primes_chiffre, net_a_payer_chiffre)
  VALUES (p_employe_id, p_mois, fn_chiffrer(p_brut, p_cle), fn_chiffrer(p_primes, p_cle), fn_chiffrer(v_net, p_cle)) AS nouveau
  ON DUPLICATE KEY UPDATE
    salaire_brut_chiffre = nouveau.salaire_brut_chiffre,
    primes_chiffre       = nouveau.primes_chiffre,
    net_a_payer_chiffre  = nouveau.net_a_payer_chiffre;
END$$

CREATE DEFINER = 'rh_crypto_owner'@'%' PROCEDURE sp_lire_salaires(
    IN p_employe_id INT UNSIGNED, IN p_cle VARBINARY(32))
  READS SQL DATA SQL SECURITY DEFINER
BEGIN
  SELECT s.mois,
         fn_dechiffrer(s.salaire_brut_chiffre, p_cle) AS salaire_brut,
         fn_dechiffrer(s.primes_chiffre, p_cle)       AS primes,
         fn_dechiffrer(s.net_a_payer_chiffre, p_cle)  AS net_a_payer
    FROM salaires s WHERE s.employe_id = p_employe_id ORDER BY s.mois;
END$$
DELIMITER ;

GRANT SELECT, INSERT, UPDATE ON rh_camara.salaires TO 'rh_crypto_owner'@'%';
GRANT EXECUTE ON PROCEDURE rh_camara.sp_ecrire_salaire TO 'rh_crypto_owner'@'%';
GRANT EXECUTE ON PROCEDURE rh_camara.sp_lire_salaires TO 'rh_crypto_owner'@'%';
REVOKE SELECT, INSERT, UPDATE ON rh_camara.salaires FROM 'role_paie'@'%';
REVOKE SELECT ON rh_camara.salaires FROM 'role_drh'@'%';
GRANT EXECUTE ON PROCEDURE rh_camara.sp_ecrire_salaire TO 'role_paie'@'%';
GRANT EXECUTE ON PROCEDURE rh_camara.sp_lire_salaires  TO 'role_paie'@'%';
FLUSH PRIVILEGES;
SHOW GRANTS FOR 'role_paie'@'%';
SHOW GRANTS FOR 'role_drh'@'%';
