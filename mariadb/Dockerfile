FROM debian:bookworm

#RUN = do something while CREATING the image
#CMD = what should start when a CONTAINER is created from that image

# Update Debian's package list and install the MariaDB server package.
# MariaDB needs /run/mysqld for runtime files such as its Unix socket.
# The mariadbd process runs as the Linux user "mysql",
# so this directory must be writable by that user.
RUN apt-get update && \
    apt-get install -y mariadb-server &&\
    rm -rf /var/lib/mysql/*

COPY tools/init.sh /usr/local/bin/init.sh

RUN chmod +x /usr/local/bin/init.sh

ENTRYPOINT [ "/usr/local/bin/init.sh" ]
