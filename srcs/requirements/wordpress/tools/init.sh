#!/bin/sh

# Stop if an important command fails
set -e

# WordPress files live here
cd /var/www/html

# Wait until MariaDB is ready
echo "Waiting for MariaDB..."

until mariadb-admin ping -h"mariadb" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --silent 2>/dev/null
do
    echo "MariaDB is not ready yet..."
    sleep 2
done

echo "MariaDB is ready."

# Download WordPress only if it is not already there
if [ ! -f wp-load.php ]; then
    echo "Downloading WordPress..."
    wp core download --allow-root
fi

# Create WordPress database config only if it does not exist
if [ ! -f wp-config.php ]; then
    echo "Creating wp-config.php..."

    wp config create \
        --dbname="$MYSQL_DATABASE" \
        --dbuser="$MYSQL_USER" \
        --dbpass="$MYSQL_PASSWORD" \
        --dbhost="mariadb:3306" \
        --allow-root
fi

# Install WordPress only if it is not already installed
if ! wp core is-installed --allow-root 2>/dev/null; then
    echo "Installing WordPress..."

    wp core install \
        --url="https://$DOMAIN_NAME" \
        --title="Inception" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email \
        --allow-root

    echo "Creating normal WordPress user..."
fi

# Create normal WordPress user only if it does not already exist
if ! wp user get "$WP_USER" --allow-root >/dev/null 2>&1; then
    echo "Creating normal WordPress user..."

    wp user create "$WP_USER" "$WP_USER_EMAIL" \
        --role=author \
        --user_pass="$WP_USER_PASSWORD" \
        --allow-root
fi

# Let PHP-FPM's user own the WordPress files
chown -R www-data:www-data /var/www/html

# Start the real service in foreground
echo "Starting PHP-FPM..."

exec php-fpm8.2 -F