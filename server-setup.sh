#!/bin/bash

set -e

echo "Установка Docker..."
apt-get update
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "Установка kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

echo "Установка minikube..."
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64

echo "Установка Flux CLI..."
curl -s https://fluxcd.io/install.sh | bash

echo "Проверка версий..."
docker --version
kubectl version --client
minikube version
flux --version

echo "Запуск minikube..."
minikube start --driver=docker --cpus=4 --memory=6144 --kubernetes-version=v1.32.0

echo "Установка Flux в кластер..."
flux install

echo "Клонирование репозитория..."
cd /root
git clone https://github.com/asadullinam/deploy_practice.git
cd deploy_practice

echo "Создание namespace..."
kubectl create namespace fake-service || true
kubectl create namespace monitoring || true

echo "Применение Flux конфигурации..."
kubectl apply -f flux-config/

echo "Установка мониторинга..."
flux create source helm prometheus-community \
  --url=https://prometheus-community.github.io/helm-charts \
  --namespace=flux-system

flux create source helm grafana \
  --url=https://grafana.github.io/helm-charts \
  --namespace=flux-system

kubectl apply -f monitoring/

echo "Готово! Проверка статуса..."
kubectl get pods -A

echo ""
echo "Для доступа к сервисам используйте port-forward:"
echo "kubectl port-forward -n fake-service svc/fake-service 8000:8000 --address=0.0.0.0"
echo "kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80 --address=0.0.0.0"
echo "kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 --address=0.0.0.0"
