-- Compte admin nominatif limite a localhost
CREATE USER IF NOT EXISTS 'admin_camara'@'localhost'
  IDENTIFIED WITH caching_sha2_password BY '@@ADMIN_PW@@';
ALTER USER 'admin_camara'@'localhost' ACCOUNT UNLOCK;
GRANT ALL PRIVILEGES ON *.* TO 'admin_camara'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SELECT user, host, plugin, account_locked FROM mysql.user WHERE user = 'admin_camara';
