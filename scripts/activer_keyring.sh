#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
PD=$(docker compose exec -T db sh -c 'mysqld --no-defaults --user=mysql --verbose --help 2>/dev/null' | awk '$1=="plugin-dir"{print $2; exit}')
PD=${PD:-/usr/lib64/mysql/plugin}
echo "Repertoire des plugins : $PD"
docker compose exec -T db sh -c "ls $PD | grep -i keyring_file" || { echo "composant keyring_file introuvable"; exit 1; }
cp -n docker-compose.yml docker-compose.yml.bak; cp -n conf/mysql.cnf conf/mysql.cnf.bak
printf '{ "components": "file://component_keyring_file" }\n' > conf/mysqld.my
printf '{ "path": "/var/lib/mysql-keyring/component_keyring_file", "read_only": false }\n' > conf/component_keyring_file.cnf
mkdir -p keyring_data
docker run --rm -v "$PWD/keyring_data":/k --entrypoint chown mysql:8.4 -R 999:999 /k
docker run --rm -v "$PWD/keyring_data":/k --entrypoint chmod mysql:8.4 700 /k
grep -q default_table_encryption conf/mysql.cnf || cat >> conf/mysql.cnf <<CNF

[mysqld]
default_table_encryption         = ON
table_encryption_privilege_check = ON
innodb_redo_log_encrypt          = ON
innodb_undo_log_encrypt          = ON
innodb_temp_tablespace_encrypt   = ON
binlog_encryption                = ON
CNF
PD="$PD" python3 - <<'PY'
import os
p='docker-compose.yml'; L=open(p).read().split('\n'); out=[]
if any('mysqld.my' in l for l in L):
    raise SystemExit('compose deja modifie')
for l in L:
    out.append(l)
    if 'conf/mysql.cnf:/etc/mysql/conf.d/mysql.cnf:ro' in l:
        ind=l[:len(l)-len(l.lstrip())]
        out += [ind+'- ./conf/mysqld.my:/usr/sbin/mysqld.my:ro',
                ind+'- ./conf/component_keyring_file.cnf:'+os.environ['PD']+'/component_keyring_file.cnf:ro',
                ind+'- ./keyring_data:/var/lib/mysql-keyring']
open(p,'w').write('\n'.join(out))
PY
docker compose config -q && echo "compose valide"
docker compose up -d db
for i in $(seq 1 40); do docker compose exec -T db mysqladmin ping --silent 2>/dev/null && break; sleep 3; done
docker compose exec -T db mysqladmin ping && echo "MySQL redemarre"
