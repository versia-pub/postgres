FROM postgres:16

RUN apt-get update && apt-get -y install git build-essential postgresql-server-dev-16
RUN postgres --version
RUN git clone https://github.com/fboulnois/pg_uuidv7
RUN cd pg_uuidv7 && make && make install && ls -la

# Add a script to run the CREATE EXTENSION command
RUN printf '#!/bin/sh\npsql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION pg_uuidv7;"' > /docker-entrypoint-initdb.d/init.sh

# Make the entrypoint script executable
RUN chmod +x /docker-entrypoint-initdb.d/init.sh
CMD ["postgres"]
