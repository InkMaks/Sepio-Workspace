#!/bin/bash
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | lolcat
}
create_mysql_cnf() {
    local mysql_cnf="$HOME/.my.cnf"
    if [ ! -f "$mysql_cnf" ]; then
        log "Creating MySQL configuration file $mysql_cnf"
        cat <<EOF > "$mysql_cnf"
[client]
user=root
password=root
EOF
        # Secure the file
        chmod 600 "$mysql_cnf"
        log "MySQL configuration file created."
    else
        log "MySQL configuration file $mysql_cnf already exists."
    fi

    # Ensure the file is readable
    chmod 400 "$mysql_cnf"
    log "MySQL configuration file permissions updated."
}

execute_mysql_command() {
    local query="$1"
    mysql --defaults-file="$HOME/.my.cnf" -e "$query"
    if [ $? -ne 0 ]; then
        log "Error executing MySQL query: $query"
        exit 1
    fi
}

install_packages() {
    local package=$1
    if ! command -v "$package" &> /dev/null; then
        log "$package is not installed. Installing $package..."
        sudo apt-get update && sudo apt-get install -y "$package"
        if [ $? -ne 0 ]; then
            log "Error: Failed to install $package."
            exit 1
        fi
    else
        log "$package is already installed."
    fi
}

install_nvm() {
    if ! command -v nvm &> /dev/null; then
        log "nvm (Node Version Manager) is not installed. Installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        log "nvm installed successfully."
    else
        log "nvm is already installed."
    fi
}

schedule_updater() {
    local script_path=$(realpath "$SCRIPT_DIR/Sepio_Updater.sh")
    local cron_job="0 3 * * * $script_path >> /var/log/sepio_updater.log 2>&1"
    (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
    log "Scheduled Sepio_Updater.sh to run daily at 3:00 AM."
}

get_required_node_version() {
    local package_json_path=$1
    local required_node_version=$(jq -r '.engines.node // "16"' "$package_json_path")
    echo "$required_node_version"
}

install_node_version() {
    local node_version=$1
    if ! command -v nvm &> /dev/null; then
        log "nvm (Node Version Manager) is not installed. Installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    fi
    nvm install "$node_version"
    if [ $? -ne 0 ]; then
        log "Error: Failed to install Node.js version $node_version using nvm."
        exit 1
    fi
    nvm use "$node_version"
    log "Using Node.js version $node_version."
}

install_frontend_dependencies() {
    local frontend_dir=$1
    log "Installing frontend dependencies in $frontend_dir..."
    cd "$frontend_dir" || { log "Error: Directory $frontend_dir not found."; exit 1; }
    npm install
    if [ $? -ne 0 ]; then
        log "Error: Failed to install frontend dependencies."
        exit 1
    fi
}

install_backend_dependencies() {
    local backend_dir=$1
    log "Installing backend dependencies in $backend_dir..."
    cd "$backend_dir" || { log "Error: Directory $backend_dir not found."; exit 1; }
    npm install
    if [ $? -ne 0 ]; then
        log "Error: Failed to install backend dependencies."
        exit 1
    fi
}
check_port_availability() {
    local port=$1
    local retries=30
    local wait=3

    log "Checking if the application is available on port $port..."

    for ((i=1; i<=retries; i++)); do
        if sudo ss -tln | grep ":$port" > /dev/null; then
            log "Application is available on port $port."
            return 0
        fi
        log "Port $port is not available yet. Waiting for $wait seconds... (Attempt $i/$retries)"
        sleep $wait
    done

    log "Error: Application is not available on port $port after $((retries * wait)) seconds."
    exit 1
}

show_header() {
    echo "====================================" | lolcat
    figlet -c Sepio Installer | lolcat
    echo "====================================" | lolcat
}

# Main script execution starts here

show_header

log "Starting setup script..."

install_packages figlet
install_packages lolcat
install_packages git
install_packages jq

SCRIPT_DIR=$(dirname "$(realpath "$0")")
SEPIO_APP_DIR="$SCRIPT_DIR/Sepio-App"

install_frontend_dependencies "$SEPIO_APP_DIR/front-end"
install_backend_dependencies "$SEPIO_APP_DIR/backend"

install_nvm

log "Checking for required Node.js versions from package.json files..."
backend_node_version=$(get_required_node_version "$SEPIO_APP_DIR/backend/package.json")
log "Required Node.js version for backend: $backend_node_version"
if [ "$backend_node_version" == "null" ]; then
    log "Error: Required Node.js version for backend not specified in package.json."
    exit 1
fi
install_node_version "$backend_node_version"

frontend_node_version=$(get_required_node_version "$SEPIO_APP_DIR/front-end/package.json")
log "Required Node.js version for frontend: $frontend_node_version"
if [ "$frontend_node_version" == "null" ]; then
    log "Error: Required Node.js version for frontend not specified in package.json."
    exit 1
fi
install_node_version "$frontend_node_version"

log "Installing latest eslint-webpack-plugin..."
npm install eslint-webpack-plugin@latest --save-dev

log "Generating Prisma Client..."
npx prisma generate
if [ $? -ne 0 ]; then
    log "Error: Failed to generate Prisma Client."
    exit 1
fi
log "Prisma Client generated successfully."

log "Granting privilages for Updater and scheduling autoupdates..."
schedule_updater
cd "$SCRIPT_DIR" || { log "Error: Directory $SCRIPT_DIR not found."; exit 1; }
chmod +x Sepio_Updater.sh
sudo touch /var/log/sepio_updater.log
sudo chown "$USER:$USER" /var/log/sepio_updater.log

log "Installing MySQL server..."
sudo apt-get update && sudo apt-get install -y mysql-server
if [ $? -ne 0 ]; then
    log "Error: Failed to install MySQL server."
    exit 1
fi

log "Securing MySQL installation..."
sudo expect -c "
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"\r\"
expect \"Set root password?\"
send \"Y\r\"
expect "New password:"
send \"root\r\"
expect "Re-enter new password:"
send \"root\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
"

log "Starting MySQL service..."
sudo systemctl start mysql

log "Enabling MySQL service to start on boot..."
sudo systemctl enable --now mysql

log "Checking MySQL status..."
sudo systemctl status --quiet mysql

log "Checking MySQL port configuration..."
mysql_port=$(sudo ss -tln | grep ':3306 ')
if [ -n "$mysql_port" ]; then
    log "MySQL is running on port 3306."
    log "MySQL installation and setup completed."
else
    log "Error: MySQL is not running on port 3306."
    exit 1
fi

#log "Creating DB User..."
#cd $SEPIO_APP_DIR/backend
#node CreateUser.js

if ! command -v mysql &> /dev/null; then
    log "MySQL client is not installed. Installing..."
    sudo apt-get update && sudo apt-get install -y mysql-client
    if [ $? -ne 0 ]; then
        log "Error: Failed to install MySQL client."
        exit 1
    fi
fi

create_mysql_cnf

execute_mysql_command "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY 'root' WITH GRANT OPTION;"

execute_mysql_command "FLUSH PRIVILEGES;"

execute_mysql_command "CREATE DATABASE IF NOT EXISTS nodejs_login;"

execute_mysql_command "ALTER USER 'Main_user'@'localhost' IDENTIFIED WITH mysql_native_password BY 'Sepio_password';"

execute_mysql_command "GRANT ALL PRIVILEGES ON nodejs_login.* TO 'Main_user'@'localhost';"

execute_mysql_command "FLUSH PRIVILEGES;"

log "Database created, user modified, and privileges granted successfully."

log "Installing Redis server..."
sudo apt-get update && sudo apt-get install -y redis-server
if [ $? -ne 0 ]; then
    log "Error: Failed to install Redis server."
    exit 1
fi

log "Starting Redis service..."
sudo systemctl start redis-server

log "Enabling Redis service to start on boot..."
sudo systemctl enable redis-server

log "Checking Redis status..."
sudo systemctl is-active redis-server

log "Checking Redis port configuration..."
redis_port=$(sudo ss -tln | grep ':6379 ')
if [ -n "$redis_port" ]; then
    log "Redis is running on port 6379."
    log "Redis installation and setup completed."
else
    log "Error: Redis is not running on port 6379."
    exit 1
fi

log "Creating systemd service for React build..."
sudo bash -c "cat <<EOL > /etc/systemd/system/react-build.service
[Unit]
Description=React Build Service
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'cd $SEPIO_APP_DIR/front-end && npm run build'
User=$USER
Environment=PATH=$PATH:/usr/local/bin
Environment=NODE_ENV=production
WorkingDirectory=$SEPIO_APP_DIR/front-end

[Install]
WantedBy=multi-user.target
EOL"
if [ $? -ne 0 ]; then
    log "Error: Failed to create react-build.service."
    exit 1
fi

log "Creating systemd service for server.js..."
sudo bash -c "cat <<EOL > /etc/systemd/system/node-server.service
[Unit]
Description=Node.js Server
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'cd $SEPIO_APP_DIR/backend && node server.js'
User=$USER
Environment=PATH=$PATH:/usr/local/bin
Environment=NODE_ENV=production
WorkingDirectory=$SEPIO_APP_DIR/backend

[Install]
WantedBy=multi-user.target
EOL"
if [ $? -ne 0 ]; then
    log "Error: Failed to create node-server.service."
    exit 1
fi

log "Reloading systemd daemon to pick up the new service files..."
sudo systemctl daemon-reload
if [ $? -ne 0 ]; then
    log "Error: Failed to reload systemd daemon."
    exit 1
fi

log "Enabling react-build.service to start on boot..."
sudo systemctl enable react-build.service
if [ $? -ne 0 ]; then
    log "Error: Failed to enable react-build.service."
    exit 1
fi

log "Starting react-build.service... Please be patient, don't break up the process..."
sudo systemctl start react-build.service
if [ $? -ne 0 ]; then
    log "Error: Failed to start react-build.service."
    exit 1
fi

log "Enabling node-server.service to start on boot..."
sudo systemctl enable node-server.service
if [ $? -ne 0 ]; then
    log "Error: Failed to enable node-server.service."
    exit 1
fi

log "Starting node-server.service..."
sudo systemctl start node-server.service
if [ $? -ne 0 ]; then
    log "Error: Failed to start node-server.service."
    exit 1
fi

log "Systemd services setup completed successfully."

check_port_availability 3000

log "Setup script executed successfully."

