#!/bin/bash

set -e

# Load environment variables
source "$(dirname "$0")/project.env"

#===--- UNDER THIS LINE DON'T MODIFY ---===

# Emoji Logger
log() {
  echo -e "\033[1;34m🔹 $1\033[0m"
}

function echo_step {
    echo -e "\n🔷 $1\n"
}

if [ "$EUID" -ne 0 ]; then
  echo_step "❌ Please run as root (e.g. sudo $0 install)"
  exit 1
fi

if [[ -z "$PROJECT_NAME" || -z "$PYTHON_VERSION" ]]; then
  log "❌ Required environment variables PROJECT_NAME and PYTHON_VERSION are not set."
  exit 1
fi

# ===== Configuration =====
log "🔧 Setting up configuration..."
ACTION=$1
MODE=${1:-dev}  # pass 'prod' as first argument for production

# Get absolute path to the directory where this script is located (e.g., /opt/webstore/tools)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Assume project root is one level up from tools/
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VENV_DIR="$PROJECT_ROOT/.venv"

REQUIRED_PACKAGES=(
    build-essential curl nginx mysql-server nodejs npm certbot
    python3-certbot-nginx libmysqlclient-dev python3-pip
)

PYTHON_REQUIRED_PACKAGES=(
	build-essential pkg-config zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev
	libssl-dev libsqlite3-dev libreadline-dev libffi-dev curl
	libbz2-dev liblzma-dev libmysqlclient-dev
)

POETRY_PYTHON_DEPENDENCY=(
	python3-dev
)

PYTHON_VERSION="3.12.3"
PYTHON_MAJOR_MINOR="$(echo $PYTHON_VERSION | cut -d. -f1,2)"  # 3.12
PYTHON_BIN="python$PYTHON_MAJOR_MINOR"  # -> python3.12
PYTHON_INSTALL_DIR="/usr/local/bin/python$PYTHON_VERSION"
PYTHON_TAR="Python-$PYTHON_VERSION.tgz"
PYTHON_SRC_DIR="/tmp/Python-$PYTHON_VERSION"

GUNICORN_SOCK="/run/gunicorn.sock"

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

if [[ -z "$ACTION" ]]; then
  echo "❓ Usage: sudo $0 [install|uninstall]"
  exit 1
fi

detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    CODENAME=$VERSION_CODENAME
    ARCH=$(uname -m)
  else
    echo "❌ Cannot detect operating system"
    exit 1
  fi
}

# Install required system packages if not already present
install_if_missing() {
    local package=$1
    if ! dpkg -s "$package" &>/dev/null; then
        log "📦 Installing $package..."
        sudo apt-get install -y "$package"
    else
        log "✅ $package already installed"
    fi
}

# Check and install latest Python from source if necessary
check_python_installed() {
  # 🐍 Install latest Python from source if needed
  if ! command -v $PYTHON_BIN &>/dev/null || [ "$($PYTHON_BIN --version 2>&1 | awk '{print $2}')" != "$PYTHON_VERSION" ]; then

  	log "🔧 Install necessary packages for Python $PYTHON_VERSION"
    for pkg in "${PYTHON_REQUIRED_PACKAGES[@]}"; do
        install_if_missing "$pkg"
    done

	echo "🔧 Building Python $PYTHON_VERSION from source..."
	cd /tmp
	curl -O https://www.python.org/ftp/python/$PYTHON_VERSION/$PYTHON_TAR
	tar -xzf $PYTHON_TAR
	cd $PYTHON_SRC_DIR
	./configure --enable-optimizations
	make -j $(nproc)
	sudo make altinstall
	rm -rf /tmp/$PYTHON_TAR $PYTHON_SRC_DIR
  else
    log "✅ Python $PYTHON_VERSION already installed. Skipping build."
  fi
}

install_database() {
	if [ ! -x "$(command -v mysql)" ]; then
	  echo "🔧 Installing database engine..."
      if [[ "$ARCH" == "armv7l" ]]; then
        log "📦 Installing MySQL (ARMv7 fallback)..."
        apt install -y mysql-server
      else
        log "📦 Installing MariaDB 11.7..."
        curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | bash
        apt update
        apt install -y mariadb-server
      fi
      systemctl enable mariadb || systemctl enable mysql
      systemctl start mariadb || systemctl start mysql
	else
		log "✅ The database is already installed"
	fi
}

if [[ "$ACTION" == "install" ]]; then
	log "🚀 Starting SoftGeek stack installation (Debian-compatible deploy)..."

	detect_os

	apt update && apt upgrade -y

	check_python_installed

	log "🔧 Installing dependencies..."
	apt install -y \
		apt-transport-https lsb-release ca-certificates gnupg gnupg2 software-properties-common \
		python3-venv python3-pip libmysqlclient-dev supervisor

	# ----------------------------
	# 🧶 Node.js + npm
	# ----------------------------
	if [ ! -x "$(command -v node)" ]; then
		log "🔧 Installing Node.js 22.x and npm..."
        curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
        apt install -y nodejs
	fi

	# ----------------------------
	# 📦 Webpack + SASS
	# ----------------------------
	log "🔧 Installing Webpack and SASS globally via npm..."
	if [ ! -x "$(command -v webpack)" ]; then
		npm install -g webpack@5 webpack-cli@5
	fi

	if [ ! -x "$(command -v sass)" ]; then
		npm install -g sass@1.89.0
    fi

	install_database

	# ----------------------------
	# 🌐 Install Poetry
	# ----------------------------
	if [ ! -x "$(command -v poetry)" ]; then
		log "📦 Installing dependencies with Poetry..."
		for pkg in "${POETRY_PYTHON_DEPENDENCY[@]}"; do
			install_if_missing "$pkg"
		done
		log "📦 Installing Poetry..."
		curl -sSL https://install.python-poetry.org | $PYTHON_BIN -

		POETRY_PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
        BASHRC="$HOME/.bashrc"

        if ! grep -Fxq "$POETRY_PATH_LINE" "$BASHRC"; then
            echo "$POETRY_PATH_LINE" >> "$BASHRC"
            source ~/.bashrc

            # Apply immediately in current shell
            eval "$POETRY_PATH_LINE"
            log "✅ Added Poetry path to .bashrc"
        else
            log "ℹ️ Poetry path already present in .bashrc"
        fi

        # Source .bashrc if it exists
        if [ ! -f "$HOME/.bash_profile" ]; then
            log -e '# ~/.bash_profile\n\nif [ -f "$HOME/.bashrc" ]; then\n    source "$HOME/.bashrc"\nfi' > ~/.bash_profile
        fi
	else
		log "✅ Poetry already installed"
	fi

	if [ ! -d "$VENV_DIR" ]; then
		log "🔧 Create virtual environment for poetry"
		# Ensure Python version in Poetry
    	poetry env use $PYTHON_BIN || echo "⚠️ Could not set Poetry Python version"
	fi

	# Install project dependencies
	if [ -f "pyproject.toml" ]; then
		poetry install
	else
		log "❌ pyproject.toml not found. Cannot continue deployment."
		exit 1
	fi

	ENV_PATH="$PROJECT_ROOT/src/$PROJECT_NAME/.env"
	if [ ! -f $ENV_PATH ]; then
		log "🔧 Populate the .env file"
		cat > "$ENV_PATH" <<EOF
DEBUG=False
SECRET_KEY=$(openssl rand -hex 32)
ALLOWED_HOSTS=$DOMAIN
DATABASE_URL=mysql://$DB_USER:$DB_PASS@localhost/$DB_NAME
EOF
	fi

	log "📦 Collecting static files..."
	cd "$PROJECT_ROOT/src/webstore"
    poetry run python manage.py collectstatic --noinput

    # ------------------------------------------------------------
    # 🔧 Fix the paths and owner for the file to www-data:www-data
    # ------------------------------------------------------------
    log "🔧 Setting ownership and permissions for project files..."
    chown -R www-data:www-data "$PROJECT_ROOT"
    # Optional: secure permissions
    find "$PROJECT_ROOT" -type d -exec chmod 755 {} \;
    find "$PROJECT_ROOT" -type f -exec chmod 644 {} \;
    echo "✅ Ownership set to www-data:www-data for $PROJECT_ROOT"

	# ----------------------------
	# 🌐 Nginx + Certbot
	# ----------------------------
	log "🔧 Installing Nginx (Debian default) and Certbot..."

	if [ ! -x "$(command -v nginx)" ]; then
		log "🔧 Install nginx web server"
		apt install -y nginx
		systemctl enable nginx
        systemctl start nginx
	fi

	if [ ! -x "$(command -v certbot)" ]; then
		log "🔧 Install certbot package"
		apt install -y certbot python3-certbot-nginx
	fi

	log "✅ Installation complete!"

elif [[ "$ACTION" == "uninstall" ]]; then
	log "🧹 Uninstalling SoftGeek stack..."

	# Stop services
	systemctl stop nginx || true
	systemctl stop mariadb || systemctl stop mysql || true

	# Node.js, npm, Webpack, Sass
	log "🧹 Removing Node.js and global npm packages..."
	npm uninstall -g webpack webpack-cli sass || true
	apt purge -y nodejs npm && apt autoremove -y

	# MariaDB
	log "🧹 Removing MariaDB/MySQL..."
	apt purge -y mariadb-server mariadb-client mysql-server mysql-client && apt autoremove -y
	rm -rf /etc/mysql /var/lib/mysql

	log "🧹 Uninstalling Poetry..."
	# Remove Poetry installation
	rm -rf "$HOME/.local/share/pypoetry"
	rm -rf "$HOME/.cache/pypoetry"
	rm -f "$HOME/.local/bin/poetry"

	# Remove PATH export from .bashrc
	sed -i '/export PATH="\$HOME\/.local\/bin:\$PATH"/d' "$HOME/.bashrc"

	log "✅ Poetry uninstalled"

	# Nginx + Certbot
	log "🧹 Removing Nginx and Certbot..."
	apt purge -y nginx nginx-common certbot python3-certbot-nginx && apt autoremove -y
	rm -rf /etc/nginx /etc/letsencrypt

	log "✅ Uninstallation complete."

else
  log "❌ Unknown action: $ACTION"
  log "Usage: sudo $0 [install|uninstall]"
  exit 1
fi

# # ===== System-wide install only in production =====
# if [ "$MODE" = "prod" ]; then
#   echo "📦 Installing system packages..."
#   sudo apt update && sudo apt install -y \
#     python3 python3.10-venv python3-venv python3-pip \
#     nginx mysql-server curl nodejs npm \
#     certbot python3-certbot-nginx \
#     build-essential libmysqlclient-dev \
#     supervisor
#
#   echo "🛢️ Setting up MySQL database..."
#   sudo mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
#   sudo mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
#   sudo mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
#   sudo mysql -e "FLUSH PRIVILEGES;"
# fi
#
# # ===== Project Setup =====
# echo "📁 Creating project directory and virtual environment..."
# mkdir -p "$PROJECT_DIR"
# cd "$PROJECT_DIR"
#
#
# source "$VENV_DIR/bin/activate"
# pip install --upgrade pip
# pip install django gunicorn
# [ "$MODE" = "prod" ] && pip install mysqlclient
#
# # Check if manage.py exists
# if [ ! -f "$MANAGE" ]; then
#     echo "❌ No Django project found at $MANAGE. Please make sure the project is set up in the Git repo."
#     exit 1
# fi
#
# # ===== Settings Update =====
# echo "⚙️ Updating Django settings..."
# mkdir -p static media
#
# SETTINGS_FILE="$PROJECT_NAME/settings.py"
#
# if ! grep -q "STATIC_URL" "$SETTINGS_FILE"; then
# cat <<EOF >> "$SETTINGS_FILE"
#
# import os
# EOF
# fi
#
# if [ "$MODE" = "prod" ]; then
# cat <<EOF >> "$SETTINGS_FILE"
#
# DATABASES = {
#     'default': {
#         'ENGINE': 'django.db.backends.mysql',
#         'NAME': '$DB_NAME',
#         'USER': '$DB_USER',
#         'PASSWORD': '$DB_PASS',
#         'HOST': 'localhost',
#         'PORT': '3306',
#     }
# }
# EOF
# else
# cat <<EOF >> "$SETTINGS_FILE"
#
# DATABASES = {
#     'default': {
#         'ENGINE': 'django.db.backends.sqlite3',
#         'NAME': os.path.join(BASE_DIR, 'db.sqlite3'),
#     }
# }
# EOF
# fi
#
# cat <<EOF >> "$SETTINGS_FILE"
#
# STATIC_URL = '/static/'
# STATIC_ROOT = os.path.join(BASE_DIR, 'static')
#
# MEDIA_URL = '/media/'
# MEDIA_ROOT = os.path.join(BASE_DIR, 'media')
# EOF
#
# echo "🗃️ Applying Django migrations and collecting static files..."
# python manage.py migrate
# python manage.py collectstatic --noinput
#
# # ===== Webpack Setup (Production Only) =====
# if [ "$MODE" = "prod" ]; then
#   echo "🛠️ Setting up Webpack..."
#   npm install --save-dev webpack webpack-cli
#   mkdir -p assets/js
#   [ ! -f assets/js/index.js ] && echo "console.log('Hello Webpack');" > assets/js/index.js
#
#   if [ ! -f webpack.config.js ]; then
#     echo "📄 Creating webpack.config.js..."
#     cat <<EOF > webpack.config.js
# const path = require('path');
#
# module.exports = {
#     entry: './assets/js/index.js',
#     output: {
#         filename: 'bundle.js',
#         path: path.resolve(__dirname, 'static'),
#     },
#     mode: 'production'
# };
# EOF
#   else
#     echo "📄 webpack.config.js already exists, skipping."
#   fi
#
#   npx webpack
# fi
#
# # ===== Supervisor Config (Production Only) =====
# if [ "$MODE" = "prod" ]; then
#   echo "📋 Creating Supervisor config..."
#   sudo tee /etc/supervisor/conf.d/$PROJECT_NAME.conf > /dev/null <<EOF
# [program:$PROJECT_NAME]
# directory=$PROJECT_DIR
# command=$VENV_DIR/bin/gunicorn $PROJECT_NAME.wsgi:application \
#     --bind unix:$SOCK_FILE \
#     --workers $GUNICORN_WORKERS \
#     --threads $GUNICORN_THREADS \
#     --timeout 60
# user=www-data
# autostart=true
# autorestart=true
# stderr_logfile=/var/log/$PROJECT_NAME.err.log
# stdout_logfile=/var/log/$PROJECT_NAME.out.log
# environment=DJANGO_SETTINGS_MODULE="$PROJECT_NAME.settings",PYTHONUNBUFFERED="1"
# EOF
#
#   sudo supervisorctl reread
#   sudo supervisorctl update
#   sudo supervisorctl restart $PROJECT_NAME
#
#   # ===== Nginx Config =====
#   echo "🌐 Configuring Nginx..."
#   sudo tee /etc/nginx/conf.d/$PROJECT_NAME > /dev/null <<EOF
# server {
#     listen 80;
#     server_name $DOMAIN;
#
#     location /static/ {
#         alias $PROJECT_DIR/static/;
#     }
#
#     location /media/ {
#         alias $PROJECT_DIR/media/;
#     }
#
#     location / {
#         include proxy_params;
#         proxy_pass http://unix:$SOCK_FILE;
#     }
# 		location ~ /\.(git|env|ht) {
# 			deny all;
# 		}
# }
# EOF
#
#   sudo ln -sf /etc/nginx/conf.d/$PROJECT_NAME /etc/nginx/conf.d/
#   sudo nginx -t && sudo systemctl reload nginx
#
#   # ===== SSL with Certbot =====
#   echo "🔐 Setting up SSL with Certbot..."
#   sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN || echo "⚠️ Certbot failed. Make sure DNS is pointing."
# fi

# # === DIRENV for automatic venv activation ===
# echo "🧠 Configuring direnv for virtualenv autoload..."
# echo "source .venv/bin/activate" > "$PROJECT_DIR/.envrc"
# direnv allow "$PROJECT_DIR"
#
# # Add direnv hook to shell config if not present
# SHELL_RC="$HOME/.bashrc"
# [[ $SHELL == *zsh ]] && SHELL_RC="$HOME/.zshrc"
# if ! grep -q 'direnv hook' "$SHELL_RC"; then
#   echo 'eval "$(direnv hook bash)"' >> "$SHELL_RC"
# fi

# Save the current active venv path
# export ACTIVE_POETRY_VENV=""
#
# function cd() {
#   builtin cd "$@" || return
#
#   # Deactivate previous venv if active
#   if [[ -n "$ACTIVE_POETRY_VENV" ]]; then
#     if [[ "$VIRTUAL_ENV" == "$ACTIVE_POETRY_VENV" ]]; then
#       echo "🚫 Deactivating Poetry venv: $ACTIVE_POETRY_VENV"
#       deactivate
#     fi
#     export ACTIVE_POETRY_VENV=""
#   fi
#
#   # Check for pyproject.toml
#   if [[ -f "pyproject.toml" ]]; then
#     VENV_PATH=$(poetry env info -p 2>/dev/null)
#     if [[ -n "$VENV_PATH" && -f "$VENV_PATH/bin/activate" ]]; then
#       echo "🔁 Activating Poetry venv: $VENV_PATH"
#       source "$VENV_PATH/bin/activate"
#       export ACTIVE_POETRY_VENV="$VENV_PATH"
#     fi
#   fi
# }

# Summary
echo_step "Deployment finished successfully!"
log "🖥️	Hardware: CPU cores: ${CPU_CORES}, RAM: ${RAM_SIZE_TXT}"
log "📁	Project path: ${PROJECT_ROOT}"
log "🐍	Python version: $($PYTHON_BIN --version 2>&1)"
log "🧰	Django version: $(poetry run python -m django --version 2>&1)"
log "⚙️	Gunicorn workers: ${GUNICORN_WORKERS}, threads: ${GUNICORN_THREADS}"
