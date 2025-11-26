#!/bin/bash

# Script para levantar clusters y aplicar namespaces con Terraform
# Uso: ./scripts/apply-namespaces.sh

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables de Azure
AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-microservices-rg}"
AZURE_CLUSTER_NAME="${AZURE_CLUSTER_NAME:-microservices-cluster-prod}"

# Variables de GCP
GCP_PROJECT_ID="${GCP_PROJECT_ID:-microservices-gke-prod}"
GCP_ZONE="${GCP_ZONE:-us-central1-a}"
GCP_CLUSTER_NAME="${GCP_CLUSTER_NAME:-microservices-cluster-gke-prod}"
GCP_NODE_POOL="${GCP_NODE_POOL:-gke-prod-np-v2}"
GCP_NODE_COUNT="${GCP_NODE_COUNT:-2}"
GCP_MIN_NODES="${GCP_MIN_NODES:-1}"
GCP_MAX_NODES="${GCP_MAX_NODES:-3}"

# Variables de Terraform
TERRAFORM_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TERRAFORM_VARS=""

echo -e "${BLUE}🚀 Script para levantar clusters y aplicar namespaces${NC}"
echo ""

# Función para verificar si Azure CLI está instalado
check_azure_cli() {
    if ! command -v az &> /dev/null; then
        echo -e "${RED}❌ Azure CLI no está instalado${NC}"
        exit 1
    fi
}

# Función para verificar si gcloud está instalado
check_gcloud() {
    if ! command -v gcloud &> /dev/null; then
        echo -e "${RED}❌ gcloud CLI no está instalado${NC}"
        exit 1
    fi
}

# Función para verificar si kubectl está instalado
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}❌ kubectl no está instalado${NC}"
        exit 1
    fi
}

# Función para verificar si terraform está instalado
check_terraform() {
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}❌ Terraform no está instalado${NC}"
        exit 1
    fi
}

# Función para levantar Azure AKS
start_azure_aks() {
    echo -e "${BLUE}📦 Verificando estado de Azure AKS...${NC}"
    
    # Verificar si el cluster está pausado
    POWER_STATE=$(az aks show \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --name "$AZURE_CLUSTER_NAME" \
        --query "powerState.code" \
        --output tsv 2>/dev/null || echo "Unknown")
    
    if [ "$POWER_STATE" == "Running" ]; then
        echo -e "${GREEN}✅ Azure AKS ya está corriendo${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}⚠️  Azure AKS está pausado. Levantando...${NC}"
    
    az aks start \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --name "$AZURE_CLUSTER_NAME"
    
    echo -e "${BLUE}⏳ Esperando a que Azure AKS esté listo...${NC}"
    
    # Esperar hasta que el cluster esté Running (máximo 10 minutos)
    TIMEOUT=600
    ELAPSED=0
    while [ $ELAPSED -lt $TIMEOUT ]; do
        POWER_STATE=$(az aks show \
            --resource-group "$AZURE_RESOURCE_GROUP" \
            --name "$AZURE_CLUSTER_NAME" \
            --query "powerState.code" \
            --output tsv 2>/dev/null || echo "Unknown")
        
        if [ "$POWER_STATE" == "Running" ]; then
            echo -e "${GREEN}✅ Azure AKS está listo${NC}"
            return 0
        fi
        
        echo -e "${YELLOW}   Estado: $POWER_STATE (esperando... ${ELAPSED}s)${NC}"
        sleep 10
        ELAPSED=$((ELAPSED + 10))
    done
    
    echo -e "${RED}❌ Timeout: Azure AKS no se levantó en 10 minutos${NC}"
    exit 1
}

# Función para escalar GCP GKE
scale_gcp_gke() {
    echo -e "${BLUE}📦 Verificando estado de GCP GKE...${NC}"
    
    # Verificar número de nodos actual
    CURRENT_NODES=$(gcloud container clusters describe "$GCP_CLUSTER_NAME" \
        --zone "$GCP_ZONE" \
        --project "$GCP_PROJECT_ID" \
        --format="value(currentNodeCount)" 2>/dev/null || echo "0")
    
    # Validar que CURRENT_NODES sea un número
    if ! [[ "$CURRENT_NODES" =~ ^[0-9]+$ ]]; then
        echo -e "${YELLOW}⚠️  No se pudo obtener el número de nodos, asumiendo 0...${NC}"
        CURRENT_NODES="0"
    fi
    
    # Comparar números
    if [ "$CURRENT_NODES" -eq "$GCP_NODE_COUNT" ] || [ "$CURRENT_NODES" -ge "$GCP_NODE_COUNT" ]; then
        echo -e "${GREEN}✅ GCP GKE ya tiene $CURRENT_NODES nodos${NC}"
    else
        echo -e "${YELLOW}⚠️  GCP GKE tiene $CURRENT_NODES nodos. Escalando a $GCP_NODE_COUNT...${NC}"
        
        # Deshabilitar autoscaling temporalmente si está habilitado
        echo -e "${BLUE}   Deshabilitando autoscaling temporalmente...${NC}"
        gcloud container clusters update "$GCP_CLUSTER_NAME" \
            --zone "$GCP_ZONE" \
            --project "$GCP_PROJECT_ID" \
            --no-enable-autoscaling \
            --node-pool "$GCP_NODE_POOL" \
            2>/dev/null || echo "   (autoscaling ya estaba deshabilitado o no aplica)"
        
        # Escalar a número de nodos deseado
        echo -e "${BLUE}   Escalando node pool a $GCP_NODE_COUNT nodos...${NC}"
        gcloud container clusters resize "$GCP_CLUSTER_NAME" \
            --num-nodes "$GCP_NODE_COUNT" \
            --zone "$GCP_ZONE" \
            --project "$GCP_PROJECT_ID" \
            --node-pool "$GCP_NODE_POOL" \
            --quiet
        
        echo -e "${BLUE}⏳ Esperando a que los nodos estén listos...${NC}"
        
        # Esperar hasta que los nodos estén Ready (máximo 10 minutos)
        TIMEOUT=600
        ELAPSED=0
        while [ $ELAPSED -lt $TIMEOUT ]; do
            READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo "0")
            
            if [ "$READY_NODES" -ge "$GCP_NODE_COUNT" ]; then
                echo -e "${GREEN}✅ GCP GKE tiene $READY_NODES nodos listos${NC}"
                break
            fi
            
            echo -e "${YELLOW}   Nodos listos: $READY_NODES/$GCP_NODE_COUNT (esperando... ${ELAPSED}s)${NC}"
            sleep 10
            ELAPSED=$((ELAPSED + 10))
        done
        
        if [ "$READY_NODES" -lt "$GCP_NODE_COUNT" ]; then
            echo -e "${RED}❌ Timeout: GCP GKE no tiene suficientes nodos listos${NC}"
            exit 1
        fi
        
        # Habilitar autoscaling
        echo -e "${BLUE}   Habilitando autoscaling (min: $GCP_MIN_NODES, max: $GCP_MAX_NODES)...${NC}"
        gcloud container clusters update "$GCP_CLUSTER_NAME" \
            --zone "$GCP_ZONE" \
            --project "$GCP_PROJECT_ID" \
            --enable-autoscaling \
            --min-nodes "$GCP_MIN_NODES" \
            --max-nodes "$GCP_MAX_NODES" \
            --node-pool "$GCP_NODE_POOL"
    fi
}

# Función para preparar variables de Terraform
prepare_terraform_vars() {
    echo -e "${BLUE}📋 Preparando variables de Terraform...${NC}"
    
    TERRAFORM_VARS=""
    
    # ===== Variables de Azure =====
    # Intentar obtener desde variables de entorno o Azure CLI
    if [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
        echo -e "${BLUE}   Obteniendo subscription_id desde Azure CLI...${NC}"
        AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null || echo "")
        if [ -n "$AZURE_SUBSCRIPTION_ID" ]; then
            echo -e "${GREEN}   ✅ subscription_id obtenido: ${AZURE_SUBSCRIPTION_ID:0:8}...${NC}"
        fi
    fi
    
    if [ -z "$AZURE_TENANT_ID" ]; then
        echo -e "${BLUE}   Obteniendo tenant_id desde Azure CLI...${NC}"
        AZURE_TENANT_ID=$(az account show --query tenantId -o tsv 2>/dev/null || echo "")
        if [ -n "$AZURE_TENANT_ID" ]; then
            echo -e "${GREEN}   ✅ tenant_id obtenido: ${AZURE_TENANT_ID:0:8}...${NC}"
        fi
    fi
    
    # Client ID y Secret no se pueden obtener automáticamente, deben estar en entorno
    if [ -z "$AZURE_CLIENT_ID" ]; then
        echo -e "${YELLOW}   ⚠️  AZURE_CLIENT_ID no configurado${NC}"
        echo -e "${YELLOW}      Configura: export AZURE_CLIENT_ID='tu-client-id'${NC}"
    fi
    
    if [ -z "$AZURE_CLIENT_SECRET" ]; then
        echo -e "${YELLOW}   ⚠️  AZURE_CLIENT_SECRET no configurado${NC}"
        echo -e "${YELLOW}      Configura: export AZURE_CLIENT_SECRET='tu-client-secret'${NC}"
    fi
    
    # Construir variables de Azure si están disponibles
    if [ -n "$AZURE_SUBSCRIPTION_ID" ] && [ -n "$AZURE_TENANT_ID" ] && \
       [ -n "$AZURE_CLIENT_SECRET" ] && [ -n "$AZURE_CLIENT_ID" ]; then
        echo -e "${GREEN}   ✅ Todas las variables de Azure configuradas${NC}"
        TERRAFORM_VARS="-var=\"subscription_id=${AZURE_SUBSCRIPTION_ID}\""
        TERRAFORM_VARS="$TERRAFORM_VARS -var=\"tenant_id=${AZURE_TENANT_ID}\""
        TERRAFORM_VARS="$TERRAFORM_VARS -var=\"client_secret=${AZURE_CLIENT_SECRET}\""
        TERRAFORM_VARS="$TERRAFORM_VARS -var=\"client_id=${AZURE_CLIENT_ID}\""
    else
        echo -e "${YELLOW}   ⚠️  Variables de Azure incompletas${NC}"
        echo -e "${YELLOW}      Terraform puede solicitar estos valores interactivamente${NC}"
    fi
    
    # ===== Variables de GCP =====
    # Intentar obtener project_id desde gcloud
    if [ -z "$GCP_PROJECT_ID" ]; then
        echo -e "${BLUE}   Obteniendo GCP_PROJECT_ID desde gcloud...${NC}"
        GCP_PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
        if [ -z "$GCP_PROJECT_ID" ]; then
            GCP_PROJECT_ID="microservices-gke-prod"
            echo -e "${YELLOW}   ⚠️  Usando valor por defecto: $GCP_PROJECT_ID${NC}"
        else
            echo -e "${GREEN}   ✅ GCP_PROJECT_ID obtenido: $GCP_PROJECT_ID${NC}"
        fi
    else
        echo -e "${GREEN}   ✅ GCP_PROJECT_ID configurado: $GCP_PROJECT_ID${NC}"
    fi
    
    # Verificar credenciales de GCP
    if [ -z "$GCP_CREDENTIALS_PATH" ]; then
        GCP_CREDENTIALS_PATH="$HOME/.gcp-keys/gke-admin-key.json"
        echo -e "${BLUE}   Usando ruta por defecto para credenciales: $GCP_CREDENTIALS_PATH${NC}"
    fi
    
    if [ ! -f "$GCP_CREDENTIALS_PATH" ]; then
        echo -e "${RED}❌ Archivo de credenciales de GCP no encontrado: $GCP_CREDENTIALS_PATH${NC}"
        echo -e "${YELLOW}   Configura: export GCP_CREDENTIALS_PATH='/ruta/a/tu/key.json'${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}   ✅ Variables de GCP configuradas${NC}"
    TERRAFORM_VARS="$TERRAFORM_VARS -var=\"gcp_project_id=${GCP_PROJECT_ID}\""
    TERRAFORM_VARS="$TERRAFORM_VARS -var=\"gcp_credentials_path=${GCP_CREDENTIALS_PATH}\""
}

# Función para ejecutar Terraform
run_terraform() {
    echo -e "${BLUE}🔧 Ejecutando Terraform...${NC}"
    
    cd "$TERRAFORM_DIR"
    
    # Siempre ejecutar terraform init para asegurar que los módulos estén instalados
    echo -e "${BLUE}   Inicializando Terraform (verificando módulos)...${NC}"
    terraform init -upgrade
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Terraform init falló${NC}"
        exit 1
    fi
    
    # Ejecutar terraform apply
    echo -e "${BLUE}   Ejecutando terraform apply...${NC}"
    eval "terraform apply -auto-approve $TERRAFORM_VARS"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Terraform apply completado exitosamente${NC}"
    else
        echo -e "${RED}❌ Terraform apply falló${NC}"
        exit 1
    fi
}

# Función para verificar namespaces
verify_namespaces() {
    echo -e "${BLUE}🔍 Verificando namespaces creados...${NC}"
    
    # Verificar namespace dev en Azure AKS
    echo -e "${BLUE}   Verificando namespace 'dev' en Azure AKS...${NC}"
    az aks get-credentials \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --name "$AZURE_CLUSTER_NAME" \
        --overwrite-existing > /dev/null 2>&1
    
    if kubectl get namespace dev > /dev/null 2>&1; then
        echo -e "${GREEN}   ✅ Namespace 'dev' existe${NC}"
        kubectl get resourcequota,limitrange,networkpolicy -n dev 2>/dev/null | head -5
    else
        echo -e "${RED}   ❌ Namespace 'dev' no existe${NC}"
    fi
    
    # Verificar namespace prod en GCP GKE
    echo -e "${BLUE}   Verificando namespace 'prod' en GCP GKE...${NC}"
    gcloud container clusters get-credentials "$GCP_CLUSTER_NAME" \
        --zone "$GCP_ZONE" \
        --project "$GCP_PROJECT_ID" > /dev/null 2>&1
    
    if kubectl get namespace prod > /dev/null 2>&1; then
        echo -e "${GREEN}   ✅ Namespace 'prod' existe${NC}"
        kubectl get resourcequota,limitrange,networkpolicy -n prod 2>/dev/null | head -5
    else
        echo -e "${RED}   ❌ Namespace 'prod' no existe${NC}"
    fi
}

# Main
main() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Aplicar Namespaces con Terraform${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Verificar herramientas necesarias
    check_azure_cli
    check_gcloud
    check_kubectl
    check_terraform
    
    # Levantar Azure AKS
    start_azure_aks
    echo ""
    
    # Escalar GCP GKE
    scale_gcp_gke
    echo ""
    
    # Preparar variables de Terraform
    prepare_terraform_vars
    echo ""
    
    # Ejecutar Terraform
    run_terraform
    echo ""
    
    # Verificar namespaces
    verify_namespaces
    echo ""
    
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ✅ Proceso completado exitosamente${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
}

# Ejecutar main
main


