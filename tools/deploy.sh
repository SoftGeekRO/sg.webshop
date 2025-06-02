#!/bin/bash

set -e

# Load environment variables
source "$(dirname "$0")/project.env"

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
    	poetry env use "$(command -v $PYTHON_BIN)" || log "⚠️ Could not set Poetry Python version"
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

# Summary
echo_step "Deployment finished successfully!"
log "🖥️	Hardware: CPU cores: ${CPU_CORES}, RAM: ${RAM_SIZE_TXT}"
log "📁	Project path: ${PROJECT_ROOT}"
log "🐍	Python version: $($PYTHON_BIN --version 2>&1)"
log "🧰	Django version: $(poetry run python -m django --version 2>&1)"
log "⚙️	Gunicorn workers: ${GUNICORN_WORKERS}, threads: ${GUNICORN_THREADS}"
