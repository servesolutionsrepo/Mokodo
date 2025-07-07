#📄 Script: Setup.sh

#!/bin/bash
set -e

CLUSTER_NAME="minikube"
NETWORK_NAME="minikube-localstack"
LOCALSTACK_CONTAINER_NAME="localstack_main"
LOCALSTACK_IMAGE="localstack/localstack:latest"

# 1. Install Docker (if missing)
if ! command -v docker &> /dev/null; then
echo "🛠 Installing Docker..."
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"
echo "👉 Docker installed. Please restart your terminal or run 'newgrp docker'."
exit 0
fi

# 2. Install kubectl (if missing)
if ! command -v kubectl &> /dev/null; then
echo "🛠 Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/$(uname | tr '[:upper:]' '[:lower:]')/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/
fi

# 3. Install Minikube (if missing)
if ! command -v minikube &> /dev/null; then
echo "🛠 Installing Minikube..."
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-$(uname | tr '[:upper:]' '[:lower:]')-amd64
sudo install minikube-* /usr/local/bin/minikube
rm minikube-*
fi

# 4. Start Minikube (Docker driver)
if ! minikube status &>/dev/null; then
echo "🚀 Starting Minikube with Docker driver..."
minikube start --driver=docker
else
echo "✅ Minikube is already running."
fi

# 5. Create Docker network
echo "🌐 Creating Docker network: $NETWORK_NAME..."
docker network create "$NETWORK_NAME" || echo "✅ Network $NETWORK_NAME already exists."

# 6. Start LocalStack
echo "📦 Starting LocalStack on $NETWORK_NAME..."
docker run -d\
    --name "$LOCALSTACK_CONTAINER_NAME"\
    --network "$NETWORK_NAME"\
    -p 4566:4566 -p 4571:4571\
    -e SERVICES=s3,secretsmanager,rds,elasticache\
    -e DEBUG=1\
    "$LOCALSTACK_IMAGE"\

# 7. Connect Minikube node to the network
MINIKUBE_CONTAINER=$(docker ps --filter "name=minikube" --format "{{.Names}}" | head -n1)
echo "🔗 Connecting Minikube container ($MINIKUBE_CONTAINER) to $NETWORK_NAME..."
docker network connect "$NETWORK_NAME" "$MINIKUBE_CONTAINER" || echo "✅ Already connected."

# 8. Get LocalStack IP
LOCALSTACK_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$LOCALSTACK_CONTAINER_NAME")
echo "🌐 LocalStack IP: $LOCALSTACK_IP"

# 9. Deploy curl pod in Minikube
echo "📨 Deploying curl pod to test connectivity..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
name: curl
spec:
containers:
- name: curl
image: curlimages/curl
command: ["sleep", "3600"]
env:
- name: AWS_ACCESS_KEY_ID
value: test
- name: AWS_SECRET_ACCESS_KEY
value: test
restartPolicy: Never
EOF

echo "⏳ Waiting for pod to be ready..."
kubectl wait --for=condition=Ready pod/curl --timeout=60s

# 10. Test connectivity to LocalStack
echo "🔍 Testing connection from curl pod to LocalStack:"
kubectl exec curl -- curl -s http://$LOCALSTACK_IP:4566/health | jq .

echo "✅ Setup complete: Minikube can reach LocalStack!"

#🟡 Usage Instructions
