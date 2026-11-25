-- Restreint root uniquement a localhost
SELECT user, host FROM mysql.user WHERE user = 'root';
DELETE FROM mysql.user WHERE user = 'root' AND host NOT IN ('localhost');
FLUSH PRIVILEGES;
SELECT user, host FROM mysql.user WHERE user = 'root';
