# This is local setup script for the MPCIUM project.
set -eu

NUM_NODES=3
THRESHOLD=2
BADGER_PASSWORD=$(openssl rand -hex 16)
CONFIG_FILE="config.yaml"

# Remove the existing .mpcium directory
rm -rf .mpcium
# Remove the existing config.yaml file
rm -f $CONFIG_FILE
# Remove the existing peers.json file
rm -f peers.json
# Remove the existing event_initiator.identity.json and event_initiator.key file
rm -f event_initiator.identity.json
rm -f event_initiator.key

# First, we need to build the mpcium binary
make install
echo "[+]: Built the mpcium binary"

# Then we need to run nats server and consul server
# Stop and remove the containers
docker-compose -f ./docker-compose.yaml down -v
# Start the containers
docker-compose -f ./docker-compose.yaml up -d
echo "[+]: Started the containers: nats and consul"

# Then, we will generate the peers.json file
mpcium-cli generate-peers --number $NUM_NODES
echo "[+]: Generated the peers.json file"

# Then, we will generate initiator public key
mpcium-cli generate-initiator
INITIATOR_PUBLIC_KEY=$(cat event_initiator.identity.json | jq -r '.public_key')
echo "[+]: Generated the initiator public key: $INITIATOR_PUBLIC_KEY"

# Then, we will generate the chain code
CHAIN_CODE=$(openssl rand -hex 32)
echo "[+]: Generated the chain code: $CHAIN_CODE"

# Then, we will generate the badger password
BADGER_PASSWORD=$(openssl rand -hex 16)
echo "[+]: Generated the badger password: $BADGER_PASSWORD"

# Then we will create and update the config.yaml file
cp config.yaml.template $CONFIG_FILE
sed -i -E "s|mpc_threshold:.*|mpc_threshold: $THRESHOLD|" $CONFIG_FILE
sed -i -E "s|event_initiator_pubkey:.*|event_initiator_pubkey: $INITIATOR_PUBLIC_KEY|" $CONFIG_FILE
sed -i -E "s|chain_code:.*|chain_code: $CHAIN_CODE|" $CONFIG_FILE
sed -i -E "s|badger_password:.*|badger_password: $BADGER_PASSWORD|" $CONFIG_FILE
echo "[+]: Updated the config.yaml file"

# Then we will register the peers to Consul
mpcium-cli register-peers --peers peers.json
echo "[+]: Registered the peers to Consul"

# Next, we will create the .mpcium directory and then initialize 3 nodes
mkdir -p .mpcium
cd .mpcium
mkdir node{0..2}
for dir in node{0..2}; do cp ../config.yaml ../peers.json "$dir/"; done
echo "[+]: Created the .mpcium directory and initialized 3 nodes"

# Then, we generate the identities for each node and copy them to the corresponding node directory
# Generate the identity for each nodes
cd node0
mpcium-cli generate-identity --node node0 
cd ../node1
mpcium-cli generate-identity --node node1
cd ../node2
mpcium-cli generate-identity --node node2
cd ..
# Copy the identities to the corresponding node directory
cp node0/identity/node0_identity.json node1/identity/node0_identity.json
cp node0/identity/node0_identity.json node2/identity/node0_identity.json
cp node1/identity/node1_identity.json node0/identity/node1_identity.json
cp node1/identity/node1_identity.json node2/identity/node1_identity.json
cp node2/identity/node2_identity.json node0/identity/node2_identity.json
cp node2/identity/node2_identity.json node1/identity/node2_identity.json
echo "[+]: Generated the identities for each node and copied them to the corresponding node directory"

cd ..
rm -rf config.yaml-E

echo "[+]: Local setup completed successfully"