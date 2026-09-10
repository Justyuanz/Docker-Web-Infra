#!/bin/sh

set -eu

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld /var/lib/mysql

if [ ! -d "/var/lib/mysql/mysql" ]; then

    echo "First MariaDB startup"

    # Create MariaDB's basic system databases/files
    mariadb-install-db \
        --user=mysql \
        --datadir=/var/lib/mysql \
        --skip-test-db

    # Create SQL that we want MariaDB to run on its first real startup
    cat > /tmp/init.sql <<EOF
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF
    # Start MariaDB normally and tell it to execute init.sql
    exec mariadbd \
        --user=mysql \
        --bind-address=0.0.0.0 \
        --init-file=/tmp/init.sql
fi

# If MariaDB was already initialized, just start it normally
exec mariadbd --user=mysql --bind-address=0.0.0.0