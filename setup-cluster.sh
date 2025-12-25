#!/bin/bash

set -e

echo "Starting Minikube cluster setup with Flux..."

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Проверка установки необходимых инструментов
check_requirements() {
    echo -e "${BLUE}Checking requirements...${NC}"
    
    if ! command -v minikube &> /dev/null; then
        echo -e "${YELLOW}Minikube not found. Installing...${NC}"
        brew install minikube
    fi
    
    if ! command -v kubectl &> /dev/null; then
        echo -e "${YELLOW}kubectl not found. Installing...${NC}"
        brew install kubectl
    fi
    
    if ! command -v flux &> /dev/null; then
        echo -e "${YELLOW}Flux CLI not found. Installing...${NC}"
        brew install fluxcd/tap/flux
    fi
    
    echo -e "${GREEN}All requirements installed${NC}"
}

# Создание Minikube кластера
create_cluster() {
    echo -e "${BLUE}Creating Minikube cluster...${NC}"
    
    # Проверяем, запущен ли уже minikube
    if minikube status &> /dev/null; then
        echo -e "${YELLOW}Minikube is already running. Deleting existing cluster...${NC}"
        minikube delete
    fi
    
    # Создаем новый кластер на qemu2
    minikube start \
        --driver=qemu2 \
        --cpus=2 \
        --memory=4096 \
        --disk-size=20g \
        --kubernetes-version=v1.32.0
    
    echo -e "${GREEN}Minikube cluster created${NC}"
    echo -e "${YELLOW}Note: qemu2 driver doesn't support minikube service/tunnel.${NC}"
    echo -e "${YELLOW}Use 'kubectl port-forward' to access services.${NC}"
}

# Установка Flux
install_flux() {
    echo -e "${BLUE}Installing Flux...${NC}"
    
    # Проверяем prerequisites
    flux check --pre
    
    # Устанавливаем Flux components
    flux install
    
    # Ждем пока все поды Flux запустятся
    echo -e "${YELLOW}Waiting for Flux pods to be ready...${NC}"
    kubectl wait --for=condition=ready pod \
        --all \
        --namespace=flux-system \
        --timeout=5m
    
    echo -e "${GREEN}Flux installed${NC}"
}

# Настройка Git репозитория для Flux (опционально)
setup_git_source() {
    echo -e "${BLUE}Setting up Git source...${NC}"
    
    read -p "Do you want to configure a Git repository for Flux? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter your GitHub username: " GITHUB_USER
        read -p "Enter your repository name: " GITHUB_REPO
        read -p "Enter branch (default: main): " GITHUB_BRANCH
        GITHUB_BRANCH=${GITHUB_BRANCH:-main}
        
        echo -e "${YELLOW}Creating Git source...${NC}"
        
        flux create source git flux-system \
            --url=https://github.com/${GITHUB_USER}/${GITHUB_REPO} \
            --branch=${GITHUB_BRANCH} \
            --interval=1m \
            --export > ./flux-config/git-source.yaml
        
        kubectl apply -f ./flux-config/git-source.yaml
        
        echo -e "${GREEN}Git source configured${NC}"
    else
        echo -e "${YELLOW}Skipping Git source setup. You can configure it later.${NC}"
    fi
}

# Создание namespace для приложения
create_app_namespace() {
    echo -e "${BLUE}Creating application namespace...${NC}"
    
    kubectl create namespace fake-service || true
    kubectl create namespace monitoring || true
    
    # Включаем аддоны
    minikube addons enable ingress
    minikube addons enable metrics-server
    
    echo -e "${GREEN}Namespaces created and addons enabled${NC}"
}

# Вывод информации
print_info() {
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}Setup completed successfully${NC}"
    echo -e "${GREEN}========================================${NC}\n"
    
    echo -e "${BLUE}Cluster information:${NC}"
    kubectl cluster-info
    
    echo -e "\n${BLUE}Flux components:${NC}"
    flux get all
    
    echo -e "\n${BLUE}Useful commands:${NC}"
    echo -e "  ${YELLOW}kubectl get pods -n flux-system${NC} - Check Flux pods"
    echo -e "  ${YELLOW}flux get sources git${NC} - List Git sources"
    echo -e "  ${YELLOW}flux get kustomizations${NC} - List Kustomizations"
    echo -e "  ${YELLOW}kubectl port-forward -n fake-service svc/fake-service 8000:8000${NC} - Access fake-service"
    echo -e "  ${YELLOW}kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80${NC} - Access Grafana"
    echo -e "  ${YELLOW}minikube stop${NC} - Stop cluster"
    echo -e "  ${YELLOW}minikube delete${NC} - Delete cluster"
    
    echo -e "\n${BLUE}Next steps:${NC}"
    echo -e "  1. Configure your Git repository for GitOps"
    echo -e "  2. Deploy your application manifests"
    echo -e "  3. Set up monitoring stack (Prometheus, Grafana, Loki)"
}

# Основной процесс
main() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Minikube + Flux Setup Script${NC}"
    echo -e "${GREEN}========================================${NC}\n"
    
    check_requirements
    create_cluster
    install_flux
    create_app_namespace
    setup_git_source
    print_info
}

# Запуск
main
