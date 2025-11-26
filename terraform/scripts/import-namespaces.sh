#!/bin/bash

# Script para importar namespaces existentes al estado de Terraform
# Uso: ./scripts/import-namespaces.sh

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

TERRAFORM_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo -e "${BLUE}📥 Importando namespaces existentes al estado de Terraform${NC}"
echo ""

cd "$TERRAFORM_DIR"

# Importar namespace 'dev' en Azure AKS
echo -e "${BLUE}📦 Importando namespace 'dev' en Azure AKS...${NC}"
az aks get-credentials \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$AZURE_CLUSTER_NAME" \
  --overwrite-existing > /dev/null 2>&1

if kubectl get namespace dev > /dev/null 2>&1; then
  echo -e "${GREEN}   ✅ Namespace 'dev' existe${NC}"
  terraform import module.namespace_dev.kubernetes_namespace.namespace dev 2>/dev/null || {
    echo -e "${YELLOW}   ⚠️  Namespace 'dev' ya está en el estado de Terraform o hubo un error${NC}"
  }
else
  echo -e "${YELLOW}   ⚠️  Namespace 'dev' no existe, se creará con terraform apply${NC}"
fi

# Importar namespace 'prod' en GCP GKE
echo -e "${BLUE}📦 Importando namespace 'prod' en GCP GKE...${NC}"
gcloud container clusters get-credentials "$GCP_CLUSTER_NAME" \
  --zone "$GCP_ZONE" \
  --project "$GCP_PROJECT_ID" > /dev/null 2>&1

if kubectl get namespace prod > /dev/null 2>&1; then
  echo -e "${GREEN}   ✅ Namespace 'prod' existe${NC}"
  terraform import 'module.namespace_prod[0].kubernetes_namespace.namespace' prod 2>/dev/null || {
    echo -e "${YELLOW}   ⚠️  Namespace 'prod' ya está en el estado de Terraform o hubo un error${NC}"
  }
else
  echo -e "${YELLOW}   ⚠️  Namespace 'prod' no existe, se creará con terraform apply${NC}"
fi

echo ""
echo -e "${GREEN}✅ Proceso de importación completado${NC}"
echo -e "${BLUE}💡 Ejecuta 'terraform plan' para verificar el estado${NC}"



