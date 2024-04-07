FROM postgres:16-alpine AS env-build

# install build dependencies
RUN apk update && apk upgrade \
  && apk add build-base postgresql-dev

WORKDIR /srv
COPY . /srv

# build extension for P16
RUN pg_buildext build-16 16

# create tarball and checksums
RUN cp sql/pg_uuidv7--1.5.sql . && TARGETS=$(find * -name pg_uuidv7.so) \
  && tar -czvf pg_uuidv7.tar.gz $TARGETS pg_uuidv7--1.5.sql pg_uuidv7.control \
  && sha256sum pg_uuidv7.tar.gz $TARGETS pg_uuidv7--1.5.sql pg_uuidv7.control > SHA256SUMS

FROM postgres:16-alpine AS env-deploy

# copy tarball and checksums
COPY --from=env-build /srv/pg_uuidv7.tar.gz /srv/SHA256SUMS /srv/

# add extension to postgres
COPY --from=env-build /srv/${PG_MAJOR}/pg_uuidv7.so /usr/lib/postgresql/${PG_MAJOR}/lib
COPY --from=env-build /srv/pg_uuidv7.control /usr/share/postgresql/${PG_MAJOR}/extension
COPY --from=env-build /srv/pg_uuidv7--1.5.sql /usr/share/postgresql/${PG_MAJOR}/extension

# Add a script to run the CREATE EXTENSION command
RUN printf '#!/bin/sh\npsql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION pg_uuidv7;"' > /docker-entrypoint-initdb.d/init.sh

# Make the entrypoint script executable
RUN chmod +x /docker-entrypoint-initdb.d/init.sh
CMD ["postgres"]
