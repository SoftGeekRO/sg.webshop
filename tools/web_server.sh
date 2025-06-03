#!/bin/bash

set -e

# Get absolute path to the directory where this script is located (e.g., /opt/webstore/tools)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Assume project root is one level up from tools/
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load environment variables
source "$(dirname "$0")/project.env"

LOCAL_IP=$(ip route get 1 | awk '{print $7; exit}')

# Default values

SUPERVISOR_PATH="/etc/supervisor/conf.d/"
GUNICORN_SOCK_FILE="$PROJECT_ROOT/var/run/gunicorn.sock"
VENV_DIR="$PROJECT_ROOT/.venv"

ERROR_PAGES_PATH="$PROJECT_ROOT/utils/nginx/errorPages"

NGINX_PATH="/etc/nginx"
NGINX_CONF="$NGINX_PATH/nginx.conf"
NGINX_CONF_DIR="$NGINX_PATH/conf.d"
NGINX_DEFAULT_SERVER="$NGINX_CONF_DIR/default.conf"

NGINX_GZIP_CONF="$NGINX_PATH/snippets/gzip.conf"
NGINX_SSL_SETTINGS="$NGINX_PATH/snippets/options-ssl-nginx.conf"
NGINX_ERROR_PAGES="$NGINX_PATH/snippets/errorPages.conf"

DH_PARAMS="/etc/letsencrypt/ssl-dhparams.pem"
SSL_DUMMY_CERT="/etc/ssl/certs/dummy.crt"
SSL_DUMMY_KEY="/etc/ssl/private/dummy.key"

# Detect system specs
CPU_CORES=$(nproc)
RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
RAM_MB=$(echo "$RAM_KB / 1024" | bc)
RAM_GB=$(echo "scale=2; $RAM_MB / 1024" | bc)


if (( RAM_MB < 1024 )); then
    RAM_SIZE_TXT="${RAM_MB} MB"
else
    RAM_SIZE_TXT="${RAM_GB} GB"
fi

# Gunicorn tuning based on hardware
if (( $(echo "$RAM_GB < 1" | bc -l) )); then
	GUNICORN_WORKERS=1
    GUNICORN_THREADS=1
elif [ "$RAM_GB" -le 1 ]; then
	GUNICORN_WORKERS=2
	GUNICORN_THREADS=1
elif [ "$RAM_GB" -le 2 ]; then
	GUNICORN_WORKERS=3
	GUNICORN_THREADS=2
else
	GUNICORN_WORKERS=$(($CPU_CORES * 2))
	GUNICORN_THREADS=4
fi

# Emoji Logger
log() {
  echo -e "\033[1;34m🔹 $1\033[0m"
}

function echo_step {
    echo -e "\n🔷 $1\n"
}

usage() {
	log "Usage: $0 domain.com [project-root] [gunicorn-socket]"
    log "  domain.com domain2.com	- Domain name to configure"
    log "  --project-root        	- (Optional) Project root path, defaults to current directory ($PROJECT_ROOT/)"
    log "  --gunicorn-socket      	- (Optional) path to Gunicorn socket, default $GUNICORN_SOCK_FILE"
    log "  -h|--help               	- display this help information"
  exit 1
}

if [ "$EUID" -ne 0 ]; then
  echo_step "❌ Please run as root (e.g. sudo $0 install)"
  exit 1
fi

if [[ -z "$PROJECT_NAME" || -z "$PYTHON_VERSION" ]]; then
  log "❌ Required environment variables PROJECT_NAME and PYTHON_VERSION are not set."
  exit 1
fi

log "🔧 Setting up Gunicorn and Nginx server"
DOMAINS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root )
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --gunicorn-socket)
      GUNICORN_SOCK_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      DOMAINS+=("$1")
      shift
      ;;
  esac
done

if [ ${#DOMAINS[@]} -eq 0 ]; then
  usage
fi

ENV_PATH="$PROJECT_ROOT/.env"
if [ ! -f $ENV_PATH ]; then
	log "🔧 Populate the .env file"
	cat > "$ENV_PATH" <<EOF
DEBUG=False
SECRET_KEY=$(openssl rand -hex 32)
ALLOWED_HOSTS=$DOMAIN[*]
DATABASE_URL=mysql://$DB_USER:$DB_PASS@localhost/$DB_NAME
EOF
chown www-data:www-data "$ENV_PATH"
chmod 600 "$ENV_PATH"
fi

if [ ! -f "$SUPERVISOR_PATH/$PROJECT_NAME.conf" ]; then
	log "📋 Creating Supervisor config..."
	chown www-data:www-data $VENV_DIR/bin/gunicorn
	chmod a+x $VENV_DIR/bin/gunicorn
    tee "$SUPERVISOR_PATH/$PROJECT_NAME.conf" > /dev/null <<EOF
[program:$PROJECT_NAME]
directory=$PROJECT_ROOT/src/webstore
command=$VENV_DIR/bin/gunicorn $PROJECT_NAME.wsgi:application \
--bind unix:$GUNICORN_SOCK_FILE --workers $GUNICORN_WORKERS --threads $GUNICORN_THREADS --timeout 60 --reload
user=www-data
autostart=true
autorestart=true
stderr_logfile=$PROJECT_ROOT/var/log/$PROJECT_NAME.err.log
stdout_logfile=$PROJECT_ROOT/var/log/$PROJECT_NAME.out.log
environment=DJANGO_SETTINGS_MODULE="$PROJECT_NAME.settings",PYTHONUNBUFFERED="1",ENV_PATH="$PROJECT_ROOT/.env"
EOF

supervisorctl reread
supervisorctl update
supervisorctl restart $PROJECT_NAME
fi

if [ ! -d "$ERROR_PAGES_PATH" ]; then
    log "📁 Create errorPages in $ERROR_PAGES_PATH"
    mkdir -p "$ERROR_PAGES_PATH"
    cp -R "$PROJECT_ROOT/utils/nginx/errorPages/" "$ERROR_PAGES_PATH"
    chown -R www-data:www-data "$ERROR_PAGES_PATH"
    chmod -R 755 "$ERROR_PAGES_PATH"
fi

# Prerequisites setup (only once)
if [ ! -f "$DH_PARAMS" ]; then
  log "🔧 Generating Diffie-Hellman parameters..."
  openssl dhparam -out "$DH_PARAMS" 2048
fi

if [ ! -f "$SSL_DUMMY_CERT" ] && [ ! -f "$SSL_DUMMY_KEY" ]; then
    log "🔧 Generate the dummy self-signed certificates"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout "$SSL_DUMMY_KEY" \
      -out "$SSL_DUMMY_CERT" \
      -subj "/CN=localhost"
fi

if [ ! -f "$NGINX_SSL_SETTINGS" ]; then
	tee "$NGINX_SSL_SETTINGS" > /dev/null <<'EOF'
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers off;

ssl_ciphers "ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";

ssl_session_timeout 1d;
ssl_session_cache shared:SSL:10m;

ssl_stapling off;
ssl_stapling_verify off;

resolver 1.1.1.1 8.8.8.8 valid=300s;
resolver_timeout 5s;
EOF
fi

log "⚠️ Remove the extra folders"
rm -rf "$NGINX_PATH/sites-available" "$NGINX_PATH/sites-enabled" 2>/dev/null

log "🔧 Tuning Nginx..."
# Backup
cp "$NGINX_CONF" "$NGINX_CONF.bak"

# Remove unwanted includes
sed -i '/include \/etc\/nginx\/modules-enabled\/\*\.conf;/d' "$NGINX_CONF"
sed -i '/include \/etc\/nginx\/sites-enabled\/\*;/d' "$NGINX_CONF"

# Ensure multi_accept on; is in the events block
if grep -q "events {" "$NGINX_CONF"; then
	if grep -q "multi_accept" "$NGINX_CONF"; then
		sed -i "/events {/,/}/ s/^\s*multi_accept.*/    multi_accept on;/" "$NGINX_CONF"
	else
		sed -i "/events {/,/}/ s/^\(\s*worker_connections.*;\)/\1\n    multi_accept on;/" "$NGINX_CONF"
	fi
else
	log "⚠️ No 'events' block found in nginx.conf"
fi

# Set worker_processes and events block
sed -i "s/^\s*worker_processes.*/worker_processes $CPU_CORES;/" "$NGINX_CONF"

# Add or update worker_rlimit_nofile
if grep -q "worker_rlimit_nofile" "$NGINX_CONF"; then
	sed -i "s/^\s*worker_rlimit_nofile.*/worker_rlimit_nofile 65535;/" "$NGINX_CONF"
else
	sed -i "/^worker_processes/a worker_rlimit_nofile 65535;" "$NGINX_CONF"
fi

# Tune events block
if grep -q "events {" "$NGINX_CONF"; then
	sed -i "/events {/,/}/ s/^\s*worker_connections.*/    worker_connections 4096;/" "$NGINX_CONF"
fi

# Ensure server_tokens off; is set inside http block
if grep -q "http {" "$NGINX_CONF"; then
	if grep -Eq "^\s*#?\s*server_tokens\s+" "$NGINX_CONF"; then
		# Uncomment and set to off
		sed -i "s/^\s*#\?\s*server_tokens\s\+\S\+;/ \tserver_tokens off;/" "$NGINX_CONF"
	fi
else
	log "⚠️ Could not find http block in $NGINX_CONF"
fi

log "🔧 Setting up gzip config in separate file..."
# Remove any old gzip directives from nginx.conf to avoid conflicts
sed -i '/^\s*#\?\s*gzip[_a-z]*\b.*/Id' "$NGINX_CONF"

# Just inform about skipping include since it's already present
log "ℹ️ Assuming nginx.conf already includes /etc/nginx/conf.d/*.conf, skipping include directive"

# Create gzip.conf only if it doesn't exist
if [ ! -f "$NGINX_GZIP_CONF" ]; then
	tee "$NGINX_GZIP_CONF" > /dev/null <<EOF
gzip on;
gzip_disable "msie6";
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_buffers 16 8k;
gzip_http_version 1.1;
gzip_types
    text/plain
    text/css
    application/json
    application/javascript
    text/xml
    application/xml
    application/xml+rss
    text/javascript;
EOF
	log "✅ Created $NGINX_GZIP_CONF"
else
	log "ℹ️  $NGINX_GZIP_CONF already exists, skipped creation"
fi

if [ ! -f "$NGINX_DEFAULT_SERVER" ]; then
    log "\n🌐 Setting up default server."
    tee "$NGINX_DEFAULT_SERVER" > /dev/null <<EOF
server {
    listen $LOCAL_IP:80 default_server http2;
    listen [::]:80 default_server http2;

    listen 443 default_server ssl http2;
    listen [::]:443 default_server ssl http2;

    server_name _;

    include $NGINX_ERROR_PAGES;

    ssl_certificate $SSL_DUMMY_CERT;
    ssl_certificate_key $SSL_DUMMY_KEY;

    return 444;
}
EOF
fi

# Loop over domains
for DOMAIN in "${DOMAINS[@]}"; do
  log "\n🌐 Setting up $DOMAIN..."

  CONF_FILE="$NGINX_CONF_DIR/$DOMAIN.conf"
  SSL_CERTIFICATE="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
  SSL_CERTIFICATE_KEY="/etc/letsencrypt/live/$DOMAIN/privkey.pem"

  if [ -f "$CONF_FILE" ]; then
    log "❌ Config file for $DOMAIN already exists. Skipping."
    continue
  fi

  cat > "$CONF_FILE" <<EOF
server {
  listen $LOCAL_IP:80 http2;
  listen [::]:80 http2;

  server_name $DOMAIN www.$DOMAIN;
  index index.php index.html;

  include $NGINX_ERROR_PAGES;

  location / {
    return 301 https://\$host\$request_uri;
  }

  location ~ \/\.well-known\/acme-challenge {
    allow all;
  }
}

server {
  listen $LOCAL_IP:443 ssl http2;
  listen [::]:443 ssl http2;

  server_name $DOMAIN www.$DOMAIN;
  index index.php index.html;

  ssl_certificate $SSL_CERTIFICATE;
  ssl_certificate_key $SSL_CERTIFICATE_KEY;
  ssl_dhparam $DH_PARAMS;
  include $NGINX_SSL_SETTINGS;

  add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
  add_header X-Content-Type-Options nosniff;
  add_header X-Frame-Options DENY;

  include $NGINX_GZIP_CONF;

  # Enable SSI globally or inside error locations only
  ssi on;

  error_page 400 401 403 404 405 408 429 500 501 502 503 504 /error.html;
  location = /error.html {
    internal;
    ssi on;
    # Set variables that will be available to SSI
    set \$error_code \$status;
    set \$error_status "\$status";
    set \$full_request "\$request";
    root $ERROR_PAGES_PATH;
  }

  location /static/ {
    alias $PROJECT_ROOT/www/static/;
    access_log off;
    expires 30d;
  }

  location /media/ {
    alias $PROJECT_ROOT/www/media/;
    access_log off;
    expires 30d;
  }

  location / {
    include proxy_params;
    proxy_pass http://unix:$GUNICORN_SOCK_FILE;
  }

  # Optional: handle .well-known for Let's Encrypt
  location ~ /\.well-known/acme-challenge {
    allow all;
    root /opt/sg.webshop/www/;
  }

  location ~ /\.(git|env|ht) {
    deny all;
  }
}
EOF

# Only get certificate if not already existing
if [ ! -f "$SSL_CERTIFICATE" ] && [ ! -f "$SSL_CERTIFICATE_KEY" ]; then
	log "🔐 Obtaining SSL cert for $DOMAIN..."
	systemctl stop nginx
	certbot certonly --standalone -d "$DOMAIN" -d "www.$DOMAIN" --non-interactive --agree-tos -m admin@$DOMAIN --redirect
else
	log "✅ SSL cert for $DOMAIN already exists. Skipping certbot.\n"
fi

done

log "🔄 Restarting Nginx..."
systemctl restart nginx

### Summary
echo_step "Deployment finished successfully!"
log "🖥️  Hardware: CPU cores: ${CPU_CORES}, RAM: ${RAM_SIZE_TXT}"
log "⚙️  Gunicorn workers: ${GUNICORN_WORKERS}, threads: ${GUNICORN_THREADS}"
log "📁 Nginx config updated: $NGINX_CONF"
log "📁 Project path: ${PROJECT_ROOT}"
log "🐍 Domains: ${DOMAINS[*]}"
