#!/bin/bash
# Improved TF2 Server Setup Script
# Exit on error
set -e

# Set up simple logging
LOGFILE="$HOME/tf2_setup.log"

# Simple logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
}

log "=== TF2 Server Setup Started ==="

echo "Starting server setup..."

# Update and install required packages
log "Installing required packages..."
echo "Installing required packages..."
sudo apt update -y
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release unattended-upgrades

# Set up Docker repository properly
log "Setting up Docker repository..."
echo "Setting up Docker repository..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Auto-detect the IP address if not provided
IPADDR=$(/sbin/ifconfig eth0 | awk '/inet / { print $2 }' | sed 's/addr://')
if [ -z "$IPADDR" ]; then
    # Try alternative method if the first fails
    IPADDR=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
fi

echo "Using IP address: $IPADDR"
log "Using IP address: $IPADDR"

# Install Docker
log "Installing Docker..."
echo "Installing Docker..."
sudo apt update -y
apt-cache policy docker-ce
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Enable and start Docker service
log "Enabling Docker service..."
echo "Enabling Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

# Create UFW Docker configuration files
log "Setting up UFW Docker configuration..."
echo "Setting up UFW Docker configuration..."
cat > /etc/ufw/after.rules.docker << 'EOF'
# BEGIN UFW AND DOCKER
*filter
:ufw-user-forward - [0:0]
:ufw-docker-logging-deny - [0:0]
:DOCKER-USER - [0:0]
-A DOCKER-USER -j ufw-user-forward
-A DOCKER-USER -j RETURN -s 10.0.0.0/8
-A DOCKER-USER -j RETURN -s 172.16.0.0/12
-A DOCKER-USER -j RETURN -s 192.168.0.0/16
-A DOCKER-USER -p udp -m udp --sport 53 --dport 1024:65535 -j RETURN
-A DOCKER-USER -j ufw-docker-logging-deny -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 192.168.0.0/16
-A DOCKER-USER -j ufw-docker-logging-deny -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 10.0.0.0/8
-A DOCKER-USER -j ufw-docker-logging-deny -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 172.16.0.0/12
-A DOCKER-USER -j ufw-docker-logging-deny -p udp -m udp --dport 0:32767 -d 192.168.0.0/16
-A DOCKER-USER -j ufw-docker-logging-deny -p udp -m udp --dport 0:32767 -d 10.0.0.0/8
-A DOCKER-USER -j ufw-docker-logging-deny -p udp -m udp --dport 0:32767 -d 172.16.0.0/12
-A DOCKER-USER -j RETURN
-A ufw-docker-logging-deny -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix "[UFW DOCKER BLOCK] "
-A ufw-docker-logging-deny -j DROP
COMMIT
# END UFW AND DOCKER
EOF

# Create UFW Docker configuration script
cat > /usr/local/bin/configure-ufw-docker.sh << 'EOF'
#!/bin/bash

# Exit on error
set -e

# Auto-detect the IP address if not provided
IPADDR=$(/sbin/ifconfig eth0 | awk '/inet / { print $2 }' | sed 's/addr://')
if [ -z "$IPADDR" ]; then
    # Try alternative method if the first fails
    IPADDR=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
fi

# Set up logging for UFW configuration
UFW_LOGFILE="$HOME/ufw_docker_config.log"

# Simple logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$UFW_LOGFILE"
}

log "=== UFW Docker Configuration Started ==="

# Check if the Docker-specific rules are already in place
log "Checking for existing Docker rules..."
if ! grep -q "BEGIN UFW AND DOCKER" /etc/ufw/after.rules; then
    log "Backing up original after.rules file..."
    # Backup the original after.rules file
    cp /etc/ufw/after.rules /etc/ufw/after.rules.bak

    log "Adding Docker-specific rules to after.rules..."
    # Append the Docker-specific rules to the after.rules file
    cat /etc/ufw/after.rules.docker >> /etc/ufw/after.rules

    echo "Added Docker-specific rules to /etc/ufw/after.rules"
else
    log "Docker-specific rules already exist - skipping..."
    echo "Docker-specific rules already exist in /etc/ufw/after.rules"
fi

# Configure UFW defaults
log "Configuring UFW defaults..."
ufw default deny incoming
ufw default allow outgoing

# Allow traffic to ports 27015 and 27020 from anywhere
log "Allowing traffic to TF2 ports (27015, 27020)..."
echo "Allowing all traffic to ports 27015 and 27020..."
ufw allow 27015
ufw allow 27020

# Allow UDP traffic from the external IP to port 9000
log "Allowing UDP traffic from $IPADDR to port 9000..."
echo "Allowing UDP traffic from $IPADDR to port 9000..."
ufw allow from $IPADDR to any port 9000 proto udp

# IMPORTANT: Also allow Docker containers to communicate with each other via the host's public IP
log "Setting up Docker container communication rules..."
echo "Allowing Docker containers to communicate on port 9000..."

# Get all Docker network subnets
DOCKER_NETWORKS=$(docker network ls --format "{{.Name}}" | grep -v "host\|none\|bridge")

if [ ! -z "$DOCKER_NETWORKS" ]; then
    log "Found Docker networks: $DOCKER_NETWORKS"
    # Allow traffic from all Docker network ranges to port 9000
    for NET in $DOCKER_NETWORKS; do
        SUBNET=$(docker network inspect $NET | grep -oP '(?<="Subnet": ")[^"]*')
        if [ ! -z "$SUBNET" ]; then
            log "Allowing traffic from Docker network $NET ($SUBNET)"
            echo "Allowing traffic from Docker network $NET ($SUBNET) to port 9000"
            ufw allow from $SUBNET to any port 9000 proto udp
        fi
    done
else
    log "No custom Docker networks found"
fi

# Always allow the default Docker bridge network
log "Allowing default Docker bridge network..."
ufw allow from 172.17.0.0/16 to any port 9000 proto udp

# For Docker containers
log "Setting up Docker routing rules..."
echo "Setting up Docker-specific rules..."
# This applies the rule to all containers that expose port 27015
ufw route allow proto tcp from any to any port 27015
ufw route allow proto udp from any to any port 27015

# This applies the rule to all containers that expose port 27020
ufw route allow proto tcp from any to any port 27020
ufw route allow proto udp from any to any port 27020

# This applies the rule to all containers that expose port 9000
# Allow from Docker networks and specific external IP
ufw route allow proto udp from $IPADDR to any port 9000
ufw route allow proto udp from 172.17.0.0/16 to any port 9000

# Reload UFW to apply all changes
log "Reloading UFW..."
echo "Reloading UFW..."
ufw reload

# Enable UFW non-interactively
log "Enabling UFW..."
echo "Enabling UFW..."
ufw --force enable

log "=== UFW Docker Configuration Completed ==="
echo "UFW configuration complete."
EOF

# Make the UFW Docker configuration script executable
chmod +x /usr/local/bin/configure-ufw-docker.sh



# Create Docker network for RGL containers
log "Creating Docker network..."
echo "Creating Docker network for containers..."
docker network create tf2-network

# Run the TF2 server container
log "Starting TF2 server container..."
echo "Starting TF2 server container..."
docker run -d --restart=no --name=tf2 \
  --network=tf2-network \
  -p 27015:27015/udp \
  -p 27015:27015/tcp \
  -p 27020:27020/udp \
  -e STV_PASSWORD="" \
  -e RCON_PASSWORD="" \
  -e SERVER_PASSWORD="" \
  -e DEMOS_TF_APIKEY="" \
  -e LOGS_TF_APIKEY="" \
  -e INGRESS_URL="$IPADDR:9000" \
  ghcr.io/melkortf/tf2-competitive

#docker run \
 #  -v "maps:/home/tf2/server/tf/maps" \
 #  -e "RCON_PASSWORD=foobar123" \
 #  -e "SERVER_HOSTNAME=melkor.tf" \
 #  -e "STV_NAME=melkor TV" \
 #  --network=host \
 #  ghcr.io/melkortf/tf2-base

# Configure UFW
log "Configuring firewall rules..."
echo "Configuring firewall rules..."
/usr/local/bin/configure-ufw-docker.sh

log "=== Setup completed successfully ==="
echo "Setup complete! TF2 server is now running."