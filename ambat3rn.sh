#!/bin/bash

# Menampilkan ASCII Art untuk "AmbaNode"
echo "
 █████╗ ███╗   ███╗██████╗  █████╗ ███╗   ██╗ ██████╗ ██████╗ ███████╗
██╔══██╗████╗ ████║██╔══██╗██╔══██╗████╗  ██║██╔═══██╗██╔══██╗██╔════╝
███████║██╔████╔██║██████╔╝███████║██╔██╗ ██║██║   ██║██║  ██║█████╗  
██╔══██║██║╚██╔╝██║██╔══██╗██╔══██║██║╚██╗██║██║   ██║██║  ██║██╔══╝  
██║  ██║██║ ╚═╝ ██║██████╔╝██║  ██║██║ ╚████║╚██████╔╝██████╔╝███████╗
╚═╝  ╚═╝╚═╝     ╚═╝╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝
"

# Prompt untuk user (default: root)
read -p "Masukkan nama user untuk menjalankan executor (default: root): " EXECUTOR_USER
EXECUTOR_USER=${EXECUTOR_USER:-root}

# Prompt untuk Private Key
read -sp "Masukkan PRIVATE_KEY_LOCAL: " PRIVATE_KEY_LOCAL
echo ""

# Prompt Alchemy API
echo -n "API Key Alchemy: "
read APIKEY_ALCHEMY
echo

# Prompt Gas Price
echo -n "Gas Price: "
read GAS_PRICE
echo

INSTALL_DIR="/home/$EXECUTOR_USER/t3rn"
SERVICE_FILE="/etc/systemd/system/t3rn-executor.service"
ENV_FILE="/etc/t3rn-executor.env"

# Pastikan direktori ada
mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR"

# Unduh versi terbaru dari executor
TAG=$(curl -s https://api.github.com/repos/t3rn/executor-release/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
wget "https://github.com/t3rn/executor-release/releases/download/$TAG/executor-linux-$TAG.tar.gz"

# Ekstrak file
tar -xzf executor-linux-*.tar.gz
cd executor/executor/bin

# Konfigurasi environment file
sudo bash -c "cat > $ENV_FILE" <<EOL
RPC_ENDPOINTS="{\"l2rn\": [\"https://b2n.rpc.caldera.xyz/http\"], \"arbt\": [\"https://arbitrum-sepolia.drpc.org\", \"https://arb-sepolia.g.alchemy.com/v2/'$APIKEY_ALCHEMY'\"], \"bast\": [\"https://base-sepolia-rpc.publicnode.com\", \"https://base-sepolia.g.alchemy.com/v2/'$APIKEY_ALCHEMY'\"], \"opst\": [\"https://sepolia.optimism.io\", \"https://opt-sepolia.g.alchemy.com/v2/'$APIKEY_ALCHEMY'\"], \"unit\": [\"https://unichain-sepolia.g.alchemy.com/v2/'$APIKEY_ALCHEMY'\", \"https://sepolia.unichain.org\"]}"
EOL

# Berikan hak akses ke user
sudo chown -R "$EXECUTOR_USER":"$EXECUTOR_USER" "$INSTALL_DIR"
sudo chmod 600 "$ENV_FILE"

# Buat systemd service
sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=t3rn Executor Service
After=network.target

[Service]
User=$EXECUTOR_USER
WorkingDirectory=$INSTALL_DIR/executor/executor/bin
ExecStart=$INSTALL_DIR/executor/executor/bin/executor
Restart=always
RestartSec=10
Environment=ENVIRONMENT=testnet
Environment=LOG_LEVEL=debug
Environment=LOG_PRETTY=false
Environment=EXECUTOR_PROCESS_BIDS_ENABLED=true
Environment=EXECUTOR_PROCESS_ORDERS_ENABLED=true
Environment=EXECUTOR_PROCESS_CLAIMS_ENABLED=true
Environment=EXECUTOR_MAX_L3_GAS_PRICE=$GAS_PRICE
Environment=PRIVATE_KEY_LOCAL=$PRIVATE_KEY_LOCAL
Environment=ENABLED_NETWORKS=arbitrum-sepolia,base-sepolia,optimism-sepolia,l2rn
EnvironmentFile=$ENV_FILE
Environment=EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=true

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd dan jalankan service
sudo systemctl daemon-reload
sudo systemctl enable t3rn-executor.service
sudo systemctl start t3rn-executor.service

# Tampilkan log secara real-time
echo "✅ Executor berhasil diinstall dan siap dikewer-kewer! Menampilkan log real-time.."
sudo journalctl -u t3rn-executor.service -f --no-hostname -o cat
