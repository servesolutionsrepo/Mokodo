📄 teardown-minikube-localstack.sh

#!/bin/bash
set -e

CLUSTER_NAME="minikube"
NETWORK_NAME="minikube-localstack"
LOCALSTACK_CONTAINER_NAME="localstack_main"

echo "🧹 Starting teardown of Minikube + LocalStack setup..."

# Step 1: Delete curl pod (optional cleanup)
echo "📦 Deleting curl test pod (if exists)..."
kubectl delete pod curl --ignore-not-found

# Step 2: Stop and delete Minikube cluster
if minikube status &>/dev/null; then
echo "🧨 Deleting Minikube cluster..."
minikube delete
else
echo "✅ Minikube cluster already stopped or deleted."
fi

# Step 3: Stop and remove LocalStack container
if docker ps -a --format '{{.Names}}' | grep -q "^${LOCALSTACK_CONTAINER_NAME}$"; then
echo "🛑 Stopping and removing LocalStack container..."
docker rm -f "$LOCALSTACK_CONTAINER_NAME"
else
echo "✅ LocalStack container not running."
fi

# Step 4: Remove Docker network
if docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
echo "🧯 Removing Docker network: $NETWORK_NAME"
docker network rm "$NETWORK_NAME"
else
echo "✅ Docker network $NETWORK_NAME already removed."
fi

echo "🎉 Teardown complete. Environment cleaned up!"

🟢 Usage

Save as teardown-minikube-localstack.sh:

chmod +x teardown-minikube-localstack.sh
./teardown-minikube-localstack.sh
