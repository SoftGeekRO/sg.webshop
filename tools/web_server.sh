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

NGINX_MAP_HASH_BUCKET_SIZE=128
NGINX_PATH="/etc/nginx"
NGINX_CONF="$NGINX_PATH/nginx.conf"
NGINX_CONF_DIR="$NGINX_PATH/conf.d"
NGINX_DEFAULT_SERVER="$NGINX_CONF_DIR/default.conf"

NGINX_GZIP_CONF="$NGINX_PATH/snippets/gzip.conf"
NGINX_SSL_SETTINGS="$NGINX_PATH/snippets/options-ssl-nginx.conf"
NGINX_ERROR_PAGES="$NGINX_PATH/snippets/errorPages.conf"
NGINX_CORS_ORIGINS="$NGINX_PATH/snippets/cors-origin.map"

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
	GUNICORN_WORKERS=2
    GUNICORN_THREADS=2
elif [ "$RAM_GB" -le 1 ]; then
	GUNICORN_WORKERS=3
	GUNICORN_THREADS=2
elif [ "$RAM_GB" -le 2 ]; then
	GUNICORN_WORKERS=6
	GUNICORN_THREADS=4
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
    log "  --static-subdomain		- (Optional) Define the subdomain for static files"
    log "  --media-subdomain		- (Optional) Define the subdomain for media files"
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
STATIC_SUBDOMAIN="/static/"
MEDIA_SUBDOMAIN="/media/"

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
    --static-subdomain)
      STATIC_SUBDOMAIN="$2"
      shift 2
      ;;
    --media-subdomain)
      MEDIA_SUBDOMAIN="$2"
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

# Extract base domains for CORS allowlist
CORS_ORIGINS=()
for DOMAIN in "${DOMAINS[@]}"; do
    # Convert to lowercase
    DOMAIN_LOWER=${DOMAIN,,}
    PARTS=(${DOMAIN_LOWER//./ })
    if [ ${#PARTS[@]} -ge 2 ]; then
        BASE_DOMAIN="${PARTS[-2]}.${PARTS[-1]}"
        CORS_ORIGINS+=("$BASE_DOMAIN")
    fi
done
# Join with |
CORS_REGEX=$(IFS="|" ; echo "${CORS_ORIGINS[*]}")

ENV_PATH="$PROJECT_ROOT/.env"
if [ ! -f $ENV_PATH ]; then
	log "🔧 Populate the .env file"
	cat > "$ENV_PATH" <<EOF
DEBUG=False
SECRET_KEY=$(openssl rand -hex 32)
ALLOWED_HOSTS=$DOMAIN[*]
DATABASE_URL=mysql://$DB_USER:$DB_PASS@localhost/$DB_NAME
STATIC_SUBDOMAIN=$STATIC_SUBDOMAIN
MEDIA_SUBDOMAIN=$MEDIA_SUBDOMAIN
EOF
chown www-data:www-data "$ENV_PATH"
chmod 600 "$ENV_PATH"
fi

log "🔧 Generate the CORS origin map with exact matches"
{
  echo "map \$http_origin \$cors_allow_origin {"
  echo "  default \"\";"
  for ORIGIN in "${DOMAINS[@]}"; do
    echo "  \"https://$ORIGIN\" \"https://$ORIGIN\";"
    echo "  \"https://www.$ORIGIN\" \"https://www.$ORIGIN\";"
  done
  echo "}"
} > "$NGINX_CORS_ORIGINS"
#
# if [ ! -f $NGINX_CORS_ORIGINS ]; then
# 	log "🔧 Generate the CORS file for static and media subdomains"
# 	cat > $NGINX_CORS_ORIGINS <<EOF
# map \$http_origin \$cors_valid {
#   default "";
#   ~^https?://(www\.)?(${CORS_REGEX})$ 1;
# }
# EOF
chown www-data:www-data "$NGINX_CORS_ORIGINS"
chmod 755 "$ENV_PATH"
#fi

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
environment=DJANGO_SETTINGS_MODULE="$PROJECT_NAME.settings",PYTHONUNBUFFERED="1",ENV_PATH="$PROJECT_ROOT/.env",TLDEXTRACT_CACHE="$PROJECT_ROOT/var/cache/tldextract"
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

# Ensure etag off; is set inside http block
if grep -q "http {" "$NGINX_CONF"; then
  if grep -qE "^\s*etag\s+" "$NGINX_CONF"; then
    sed -i "s/^\s*etag\s\+\S\+;/    etag off;/" "$NGINX_CONF"
    log "✅ Updated existing 'etag' directive to 'etag off;'"
  elif ! grep -q "etag" "$NGINX_CONF"; then
    sed -i "/http {/a \    etag off;" "$NGINX_CONF"
    log "✅ Injected missing 'etag off;' into nginx.conf"
  else
    log "ℹ️  'etag' directive already present (commented?), check manually if needed"
  fi
else
  log "⚠️  Could not find 'http {' block in $NGINX_CONF"
fi

# Ensure map_hash_bucket_size is defined before any map directive
if grep -q "http {" "$NGINX_CONF"; then
  if ! grep -q "map_hash_bucket_size" "$NGINX_CONF"; then
    MAP_HASH_BUCKET_SIZE=${NGINX_MAP_HASH_BUCKET_SIZE:-128}
    sed -i "/http {/a \    map_hash_bucket_size $MAP_HASH_BUCKET_SIZE;" "$NGINX_CONF"
    log "✅ Injected 'map_hash_bucket_size $MAP_HASH_BUCKET_SIZE;' into nginx.conf"
  else
    log "ℹ️  'map_hash_bucket_size' already defined in nginx.conf, skipping insertion"
  fi
else
  log "⚠️  Could not find 'http {' block in $NGINX_CONF"
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
  fullDomain=${DOMAIN,,} # Convert to lowercase
  _domain=""

  parts=(${fullDomain//./ })  # Split by dot into array
  if [ ${#parts[@]} -ge 2 ]; then
      _domain="${parts[-2]}"
  else
      log "❌ Invalid domain, check $fullDomain..."
      exit 1
  fi

  if [ -f "$CONF_FILE" ]; then
    log "❌ Config file for $fullDomain already exists. Skipping."
    continue
  fi

  cat > "$CONF_FILE" <<EOF
server {
  listen $LOCAL_IP:80 http2;
  listen [::]:80 http2;

  server_name $fullDomain www.$fullDomain;
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

  server_name $fullDomain www.$fullDomain;
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

  location = /favicon.ico {
    access_log off;
    log_not_found off;
    try_files $PROJECT_ROOT/www/static/img/$_domain/icons/favicon.ico =204;
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
	log "🔐 Obtaining SSL cert for $fullDomain..."
	systemctl stop nginx
	certbot certonly --standalone -d "$fullDomain" -d "www.$fullDomain" --non-interactive --agree-tos -m admin@$fullDomain --redirect
else
	log "✅ SSL cert for $fullDomain already exists. Skipping certbot.\n"
fi
done

STATIC_CONF_FILE="$NGINX_CONF_DIR/$STATIC_SUBDOMAIN.conf"
STATIC_SSL_CERTIFICATE="/etc/letsencrypt/live/$STATIC_SUBDOMAIN/fullchain.pem"
STATIC_SSL_CERTIFICATE_KEY="/etc/letsencrypt/live/$STATIC_SUBDOMAIN/privkey.pem"

if [ ! -f "$STATIC_CONF_FILE" ]; then
	log "\n🌐 Setting up $STATIC_SUBDOMAIN"

	cat > "$STATIC_CONF_FILE" <<EOF
server {
  listen $LOCAL_IP:80 http2;
  listen [::]:80 http2;

  server_name $STATIC_SUBDOMAIN www.$STATIC_SUBDOMAIN;
  index index.php index.html;

  include $NGINX_ERROR_PAGES;

  location / {
    return 301 https://\$host\$request_uri;
  }

  location ~ /\.well-known/acme-challenge {
    allow all;
    root /opt/sg.webshop/www/;  # Adjust if needed
  }
}
include $NGINX_CORS_ORIGINS;

server {
  listen $LOCAL_IP:443 ssl http2;
  listen [::]:443 ssl http2;

  server_name $STATIC_SUBDOMAIN www.$STATIC_SUBDOMAIN;
  index index.php index.html;

  ssl_certificate $STATIC_SSL_CERTIFICATE;
  ssl_certificate_key $STATIC_SSL_CERTIFICATE_KEY;
  ssl_dhparam $DH_PARAMS;
  include $NGINX_SSL_SETTINGS;

  add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
  add_header X-Content-Type-Options nosniff;
  add_header X-Frame-Options DENY;

  include $NGINX_GZIP_CONF;

  # Enable SSI globally or inside error locations only
  ssi on;

  root $PROJECT_ROOT/www/static;

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

  location ~ ^/(.*?[a-z0-9_-]+\.[a-f0-9]+\.[a-z]+)$ {
    alias $PROJECT_ROOT/www/static/\$1;
    access_log off;
    expires 30d;

    add_header cache-control "public, immutable";
    add_header Access-Control-Allow-Origin "\$cors_allow_origin" always;
    add_header Access-Control-Allow-Methods "GET, OPTIONS" always;
    add_header Access-Control-Allow-Headers "*" always;
    add_header Vary "Origin";

    if (\$request_method = OPTIONS) {
      add_header Content-Length 0;
      add_header Content-Type text/plain;
      return 204;
    }
  }

  location ~* \.(woff2?|ttf|otf|eot)$ {
    root $PROJECT_ROOT/www/static;

    access_log off;
    expires 30d;

    add_header Access-Control-Allow-Origin "\$cors_allow_origin" always;
    add_header Access-Control-Allow-Methods "GET, OPTIONS" always;
    add_header Access-Control-Allow-Headers "*" always;
    add_header Vary "Origin";

    if (\$request_method = OPTIONS) {
      add_header Content-Length 0;
      add_header Content-Type text/plain;
      return 204;
    }
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
if [ ! -f "$STATIC_SSL_CERTIFICATE" ] && [ ! -f "$STATIC_SSL_CERTIFICATE_KEY" ]; then
	log "🔐 Obtaining SSL cert for $STATIC_SUBDOMAIN..."
	systemctl stop nginx
	certbot certonly --standalone -d "$STATIC_SUBDOMAIN" --non-interactive --agree-tos -m admin@$STATIC_SUBDOMAIN --redirect
else
	log "✅ SSL cert for $DOMAIN already exists. Skipping certbot.\n"
fi

fi

MEDIA_CONF_FILE="$NGINX_CONF_DIR/$MEDIA_SUBDOMAIN.conf"
MEDIA_SSL_CERTIFICATE="/etc/letsencrypt/live/$MEDIA_SUBDOMAIN/fullchain.pem"
MEDIA_SSL_CERTIFICATE_KEY="/etc/letsencrypt/live/$MEDIA_SUBDOMAIN/privkey.pem"

if [ ! -f "$MEDIA_CONF_FILE" ]; then
	log "\n🌐 Setting up $MEDIA_SUBDOMAIN"

	cat > "$MEDIA_CONF_FILE" <<EOF
server {
  listen $LOCAL_IP:80 http2;
  listen [::]:80 http2;

  server_name $MEDIA_SUBDOMAIN www.$MEDIA_SUBDOMAIN;
  index index.php index.html;

  include $NGINX_ERROR_PAGES;

  location / {
    return 301 https://\$host\$request_uri;
  }

  location ~ /\.well-known/acme-challenge {
    allow all;
    root /opt/sg.webshop/www/;  # Adjust if needed
  }
}

server {
  listen $LOCAL_IP:443 ssl http2;
  listen [::]:443 ssl http2;

  server_name $MEDIA_SUBDOMAIN www.$MEDIA_SUBDOMAIN;
  index index.php index.html;

  ssl_certificate $MEDIA_SSL_CERTIFICATE;
  ssl_certificate_key $MEDIA_SSL_CERTIFICATE_KEY;
  ssl_dhparam $DH_PARAMS;
  include $NGINX_SSL_SETTINGS;

  add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
  add_header X-Content-Type-Options nosniff;
  add_header X-Frame-Options DENY;

  include $NGINX_GZIP_CONF;

  # Enable SSI globally or inside error locations only
  ssi on;

  root $PROJECT_ROOT/www/media;

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

  location ~ ^/(.*?[a-z0-9_-]+\.[a-f0-9]+\.[a-z]+)$ {
    alias $PROJECT_ROOT/www/media/\$1;
    access_log off;
    expires 30d;

    add_header cache-control "public, immutable";
    add_header Access-Control-Allow-Origin "https?://(www\.)?(${CORS_REGEX})" always;
    add_header Access-Control-Allow-Methods "GET, OPTIONS" always;
    add_header Access-Control-Allow-Headers "*" always;
    add_header Vary "Origin";

    if (\$request_method = OPTIONS) {
      add_header Content-Length 0;
      add_header Content-Type text/plain;
      return 204;
    }
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
if [ ! -f "$MEDIA_SSL_CERTIFICATE" ] && [ ! -f "$MEDIA_SSL_CERTIFICATE_KEY" ]; then
	log "🔐 Obtaining SSL cert for $MEDIA_SUBDOMAIN..."
	systemctl stop nginx
	certbot certonly --standalone -d "$MEDIA_SUBDOMAIN" --non-interactive --agree-tos -m admin@$MEDIA_SUBDOMAIN --redirect
else
	log "✅ SSL cert for $MEDIA_SUBDOMAIN already exists. Skipping certbot.\n"
fi

fi


log "🔄 Restarting Nginx..."
systemctl restart nginx

### Summary
echo_step "Deployment finished successfully!"
log "🖥️  Hardware: CPU cores: ${CPU_CORES}, RAM: ${RAM_SIZE_TXT}"
log "⚙️  Gunicorn workers: ${GUNICORN_WORKERS}, threads: ${GUNICORN_THREADS}"
log "📁 Nginx config updated: $NGINX_CONF"
log "📁 Project path: ${PROJECT_ROOT}"
log "🐍 Domains: ${DOMAINS[*]}"
