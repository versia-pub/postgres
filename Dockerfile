FROM postgres:17-alpine AS env-build

# Install build dependencies in Alpine
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    libpq \
    linux-headers \
    git

# Set working directory and copy files
WORKDIR /srv
RUN git clone https://github.com/fboulnois/pg_uuidv7.git /srv

# Create directories for each PostgreSQL version to avoid copy errors
RUN for v in `seq 13 17`; do \
      mkdir -p /usr/lib/postgresql/$v/lib; \
    done

# Build extension for all supported versions
RUN for v in `seq 13 17`; do \
      echo "Building for PostgreSQL version $v"; \
      make USE_PGXS=1; \
      cp pg_uuidv7.so /usr/lib/postgresql/$v/lib/; \
    done

# Create tarball and checksums
RUN cp sql/pg_uuidv7--1.6.sql . && \
    TARGETS=$(find * -name pg_uuidv7.so) && \
    tar -czvf pg_uuidv7.tar.gz $TARGETS pg_uuidv7--1.6.sql pg_uuidv7.control && \
    sha256sum pg_uuidv7.tar.gz $TARGETS pg_uuidv7--1.6.sql pg_uuidv7.control > SHA256SUMS

FROM postgres:17-alpine AS env-deploy

# Add extension to postgres
COPY --from=0 /srv/pg_uuidv7.so /usr/local/lib/postgresql/pg_uuidv7
COPY --from=0 /srv/pg_uuidv7.control /usr/local/share/postgresql/extension
COPY --from=0 /srv/pg_uuidv7--1.6.sql /usr/local/share/postgresql/extension

# Add a script to run the CREATE EXTENSION command
RUN printf '#!/bin/sh\npsql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION pg_uuidv7;"' > /docker-entrypoint-initdb.d/init.sh

# Make the entrypoint script executable
RUN chmod +x /docker-entrypoint-initdb.d/init.sh
CMD ["postgres"]
