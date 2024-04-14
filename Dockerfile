FROM postgres:16-alpine AS env-build

RUN apk add --no-cache build-base postgresql-dev git

WORKDIR /srv
# Copy contents of https://github.com/fboulnois/pg_uuidv7.git into srv
RUN git clone https://github.com/fboulnois/pg_uuidv7.git .
COPY pg_buildext .

# build extension for all supported versions
RUN /bin/sh pg_buildext build-16 16

# create tarball and checksums
RUN cp sql/pg_uuidv7--1.5.sql . && TARGETS=$(find * -name pg_uuidv7.so) \
  && tar -czvf pg_uuidv7.tar.gz $TARGETS pg_uuidv7--1.5.sql pg_uuidv7.control \
  && sha256sum pg_uuidv7.tar.gz $TARGETS pg_uuidv7--1.5.sql pg_uuidv7.control > SHA256SUMS

FROM postgres:16-alpine AS env-deploy

# copy tarball and checksums
COPY --from=0 /srv/pg_uuidv7.tar.gz /srv/SHA256SUMS /srv/

# add extension to postgres
COPY --from=0 /srv/${PG_MAJOR}/pg_uuidv7.so /usr/local/lib/postgresql/pg_uuidv7
COPY --from=0 /srv/pg_uuidv7.control /usr/local/share/postgresql/extension
COPY --from=0 /srv/pg_uuidv7--1.5.sql /usr/local/share/postgresql/extension

# Add a script to run the CREATE EXTENSION command
RUN printf '#!/bin/sh\npsql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION pg_uuidv7;"' > /docker-entrypoint-initdb.d/init.sh

# Make the entrypoint script executable
RUN chmod +x /docker-entrypoint-initdb.d/init.sh
CMD ["postgres"]
