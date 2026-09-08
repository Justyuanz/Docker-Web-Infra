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
CREATE DATABASE IF NOT EXISTS wordpress;
CREATE USER IF NOT EXISTS 'wpuser'@'%' IDENTIFIED BY 'temporary-learning-password';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'%';
FLUSH PRIVILEGES;
EOF

    # Start MariaDB normally and tell it to execute init.sql
    exec mariadbd \
        --user=mysql \
        --init-file=/tmp/init.sql
fi

# If MariaDB was already initialized, just start it normally
exec mariadbd --user=mysql