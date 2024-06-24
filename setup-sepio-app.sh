#!/bin/bash

# Initialize progress bar
TOTAL_STEPS=20  # Total number of steps in the installation process
CURRENT_STEP=0

update_progress() {
    local step_message=$1
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local progress=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    echo "$progress"
    echo "$progress" | dialog --keep-tite --gauge "$step_message" 10 70 0
    sleep 1  # Simulate time taken by each step
}

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | lolcat
}

error_log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | lolcat
    echo "ERROR: $1" | dialog --msgbox 10 50
    exit 1
}

install_packages() {
    local package=$1
    if ! command -v "$package" &> /dev/null; then
        log "$package is not installed. Installing $package..."
        sudo apt-get update && sudo apt-get install -y "$package"
        if [ $? -ne 0 ]; then
            error_log "Error: Failed to install $package."
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

install_npm() {
    if ! command -v npm &> /dev/null; then
        log "npm is not installed. Installing npm..."
        sudo apt-get update && sudo apt-get install -y npm
        if [ $? -ne 0 ]; then
            error_log "Error: Failed to install npm."
        fi
        log "npm installed successfully."
    else
        log "npm is already installed."
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
        error_log "Error: Failed to install Node.js version $node_version using nvm."
    fi
    nvm use "$node_version"
    log "Using Node.js version $node_version."
}

install_frontend_dependencies() {
    local frontend_dir=$1
    log "Installing frontend dependencies in $frontend_dir..."
    cd "$frontend_dir" || { error_log "Error: Directory $frontend_dir not found."; }
    npm install
    if [ $? -ne 0 ]; then
        error_log "Error: Failed to install frontend dependencies."
    fi
}

install_backend_dependencies() {
    local backend_dir=$1
    log "Installing backend dependencies in $backend_dir..."
    cd "$backend_dir" || { error_log "Error: Directory $backend_dir not found."; }
    npm install
    if [ $? -ne 0 ]; then
        error_log "Error: Failed to install backend dependencies."
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

    error_log "Error: Application is not available on port $port after $((retries * wait)) seconds."
}

show_header() {
    echo "====================================" | lolcat
    figlet -c Sepio Installer | lolcat
    echo "====================================" | lolcat
}

# Main script execution starts here

show_header

install_packages dialog
log "Starting setup script..."

# Open a dialog gauge
{
    update_progress "Installing required packages..."
    install_packages figlet
    install_packages lolcat
    install_packages git
    install_packages jq
    install_packages expect

    SCRIPT_DIR=$(dirname "$(realpath "$0")")
    SEPIO_APP_DIR="$SCRIPT_DIR/Sepio-App"

    update_progress "Installing npm and deps..."
    install_npm
    install_frontend_dependencies "$SEPIO_APP_DIR/front-end"
    install_backend_dependencies "$SEPIO_APP_DIR/backend"

    install_nvm

    update_progress "Checking for required Node.js versions..."
    backend_node_version=$(get_required_node_version "$SEPIO_APP_DIR/backend/package.json")
    log "Required Node.js version for backend: $backend_node_version"
    if [ "$backend_node_version" == "null" ]; then
        error_log "Error: Required Node.js version for backend not specified in package.json."
    fi
    install_node_version "$backend_node_version"

    frontend_node_version=$(get_required_node_version "$SEPIO_APP_DIR/front-end/package.json")
    log "Required Node.js version for frontend: $frontend_node_version"
    if [ "$frontend_node_version" == "null" ]; then
        error_log "Error: Required Node.js version for frontend not specified in package.json."
    fi
    install_node_version "$frontend_node_version"

    update_progress "Installing latest eslint-webpack-plugin..."
    npm install eslint-webpack-plugin@latest --save-dev

    update_progress "Generating Prisma Client..."
    npx prisma generate
    if [ $? -ne 0 ]; then
        error_log "Error: Failed to generate Prisma Client."
    fi
    log "Prisma Client generated successfully."

    update_progress "Granting privileges for Updater and scheduling auto updates..."
    schedule_updater
    cd "$SCRIPT_DIR" || { error_log "Error: Directory $SCRIPT_DIR not found."; }
    chmod +x Sepio_Updater.sh
    sudo touch /var/log/sepio_updater.log
    sudo chown "$USER:$USER" /var/log/sepio_updater.log

    update_progress "Installing MySQL server..."
    sudo apt-get update && sudo apt-get install -y mysql-server
    if [ $? -ne 0 ]; then
        error_log "Error: Failed to install MySQL server."
    fi

    update_progress "Securing MySQL installation..."
    sudo expect -c "
    spawn mysql_secure_installation
    expect \"VALIDATE PASSWORD COMPONENT?\" {
        send -- \"Y\r\"
        expect \"There are three levels of password validation policy:\"
        send -- \"1\r\"  # Choose MEDIUM (or 2 for STRONG if needed)
    }

    expect \"Remove anonymous users?\" {
        send -- \"Y\r\"
    }

    expect \"Disallow root login remotely?\" {
        send -- \"Y\r\"
    }

    expect \"Remove test database and access to it?\" {
        send -- \"Y\r\"
    }

    expect \"Reload privilege tables now?\" {
        send -- \"Y\r\"
    }
    expect eof
    "

    update_progress "Starting MySQL service..."
    sudo systemctl start mysql

    update_progress "Enabling MySQL service to start on boot..."
    sudo systemctl enable mysql

    update_progress "Checking MySQL status..."
    sudo systemctl is-active mysql

    update_progress "Checking MySQL port configuration..."
    mysql_port=$(sudo ss -tln | grep ':3306 ')
    if [ -n "$mysql_port" ]; then
        log "MySQL is running on port 3306."
    else
        error_log "Error: MySQL is not running on port 3306."
    fi

    update_progress "Creating MySQL user and database..."
    sudo mysql <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS nodejs_login;
USE nodejs_login;

CREATE USER 'Main_user'@'localhost' IDENTIFIED BY 'Sepio_password';
GRANT ALL PRIVILEGES ON nodejs_login.* TO 'Main_user'@'localhost';
FLUSH PRIVILEGES;

CREATE TABLE IF NOT EXISTS user (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    password VARCHAR(255) NOT NULL,
    otp_secret VARCHAR(255),
    otp_verified BOOLEAN DEFAULT FALSE
);
CREATE TABLE IF NOT EXISTS ServiceNowCredentials (
  id INT AUTO_INCREMENT PRIMARY KEY,
  instance VARCHAR(255) NOT NULL,
  username VARCHAR(255) NOT NULL,
  password VARCHAR(255) NOT NULL
);
CREATE TABLE IF NOT EXISTS sepio (
  id INT AUTO_INCREMENT PRIMARY KEY,
  instance VARCHAR(255) NOT NULL,
  username VARCHAR(255) NOT NULL,
  password VARCHAR(255) NOT NULL
);
MYSQL_SCRIPT

    if [ $? -ne 0 ]; then
        error_log "Error: Failed to create MySQL user Main_user."
    fi

    log "MySQL user Main_user created successfully."

    update_progress "Installing Redis server..."
    sudo apt-get update && sudo apt-get install -y redis-server
    if [ $? -ne 0 ]; then
        error_log "Error: Failed to install Redis server."
    fi

    update_progress "Starting Redis service..."
    sudo systemctl start redis-server

    update_progress "Enabling Redis service to start on boot..."
    sudo systemctl enable redis-server

    update_progress "Checking Redis status..."
    sudo systemctl is-active redis-server

    update_progress "Checking Redis port configuration..."
    redis_port=$(sudo ss -tln | grep ':6379 ')
    if [ -n "$redis_port" ]; then
        log "Redis is running on port 6379."
        log "Redis installation and setup completed."
    else
        error_log "Error: Redis is not running on port 6379."
    fi

    update_progress "Creating systemd service for React build..."
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
        error_log "Error: Failed to create react-build.service."
    fi

    update_progress "Creating systemd service for server.js..."
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
        error_log "Error: Failed to create node-server.service."
    fi

    update_progress "Reloading systemd daemon to pick up the new service files..."
    sudo systemctl daemon-reload
    if [ $? -ne 0 ]; then
        error_log "Error: Failed to reload systemd daemon."
    fi

    update_progress "Enabling react-build.service to start on boot..."
    sudo systemctl enable react-build.service
    if [ $? -ne 0 ]; then
        error_log "Error: Failed to enable react-build.service."
    fi

    update_progress "Starting react-build.service... Please be patient, don't break up the process..."
    sudo systemctl start react-build.service
    if [ $? -ne 0 ]; then
        error_log "Error: Failed to start react-build.service."
    fi

    update_progress "Enabling node-server.service to start on boot..."
    sudo systemctl enable node-server.service
    if [ $? -ne 0 ]; then
        error_log "Error: Failed to enable node-server.service."
    fi

    update_progress "Starting node-server.service..."
    sudo systemctl start node-server.service
    if [ $? -ne 0 ]; then
        error_log "Error: Failed to start node-server.service."
    fi

    update_progress "Checking application availability..."
    check_port_availability 3000

    log "Setup script executed successfully."
} | dialog --gauge "Starting installation..." 10 70 0