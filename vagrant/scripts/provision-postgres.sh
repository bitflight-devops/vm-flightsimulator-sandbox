#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# provision-postgres.sh
# Installs PostgreSQL 16 from the official pgdg APT repo, creates the petpoll
# database and user, seeds the votes table, and opens remote access from the
# private network subnet (192.168.56.0/24).
# ──────────────────────────────────────────────────────────────────────────────

PGVERSION=16
DB_NAME=petpoll
DB_USER=petpoll_user
DB_PASS=petpoll_pass
ALLOWED_SUBNET=192.168.56.0/24

echo "==> Updating package index"
apt-get update -qq

echo "==> Installing prerequisites for pgdg repo"
apt-get install -y -qq curl ca-certificates gnupg lsb-release

echo "==> Adding PostgreSQL APT repository (pgdg)"
install -d /usr/share/postgresql-common/pgdg
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc |
	gpg --dearmor -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.gpg

echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.gpg] \
https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
	>/etc/apt/sources.list.d/pgdg.list

apt-get update -qq

echo "==> Installing postgresql-${PGVERSION}"
apt-get install -y -qq postgresql-${PGVERSION}

echo "==> Enabling and starting postgresql service"
systemctl enable postgresql
systemctl start postgresql

echo "==> Creating database user and database"
sudo -u postgres psql <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${DB_USER}') THEN
    CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';
  END IF;
END
\$\$;

SELECT 'CREATE DATABASE ${DB_NAME} OWNER ${DB_USER}'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${DB_NAME}')
\gexec

GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
SQL

echo "==> Creating votes table and seeding pet names"
sudo -u postgres psql -d "${DB_NAME}" <<SQL
CREATE TABLE IF NOT EXISTS votes (
  pet_name VARCHAR(50) PRIMARY KEY,
  count    INTEGER NOT NULL DEFAULT 0
);

INSERT INTO votes (pet_name, count) VALUES
  ('Luna',    0),
  ('Bella',   0),
  ('Max',     0),
  ('Charlie', 0),
  ('Cooper',  0),
  ('Buddy',   0),
  ('Daisy',   0),
  ('Bailey',  0),
  ('Milo',    0),
  ('Molly',   0),
  ('Cleo',    0),
  ('Oliver',  0),
  ('Leo',     0),
  ('Lola',    0),
  ('Zeus',    0),
  ('Nala',    0),
  ('Simba',   0),
  ('Rocky',   0),
  ('Rosie',   0),
  ('Biscuit', 0)
ON CONFLICT (pet_name) DO NOTHING;
SQL

echo "==> Granting table privileges to ${DB_USER}"
sudo -u postgres psql -d "${DB_NAME}" <<SQL
GRANT ALL PRIVILEGES ON TABLE votes TO ${DB_USER};
SQL

echo "==> Configuring postgresql.conf: listen on all interfaces"
PG_CONF=$(sudo -u postgres psql -t -c "SHOW config_file;" | tr -d '[:space:]')
sed -i "s/^#*listen_addresses\s*=.*/listen_addresses = '*'/" "${PG_CONF}"

echo "==> Adding pg_hba.conf entry for ${ALLOWED_SUBNET}"
PG_HBA=$(sudo -u postgres psql -t -c "SHOW hba_file;" | tr -d '[:space:]')
# Only add if not already present
grep -qF "${ALLOWED_SUBNET}" "${PG_HBA}" ||
	echo "host  ${DB_NAME}  ${DB_USER}  ${ALLOWED_SUBNET}  md5" >>"${PG_HBA}"

echo "==> Restarting PostgreSQL"
systemctl restart postgresql

echo "==> PostgreSQL ${PGVERSION} provisioning complete"
