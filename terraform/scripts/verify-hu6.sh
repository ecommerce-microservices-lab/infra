#!/bin/bash

# Script para verificar la HU6 - Kubernetes Namespaces con políticas
# Uso: ./scripts/verify-hu6.sh

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

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Verificación HU6 - Kubernetes Namespaces${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Contador de verificaciones
PASSED=0
FAILED=0

# Función para verificar y reportar
check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}❌ $1${NC}"
        ((FAILED++))
        return 1
    fi
}

# ===== Verificación Azure AKS - Namespace 'dev' =====
echo -e "${BLUE}📦 Verificando namespace 'dev' en Azure AKS...${NC}"
echo ""

# Obtener credenciales de Azure AKS
az aks get-credentials \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$AZURE_CLUSTER_NAME" \
  --overwrite-existing > /dev/null 2>&1

# Verificar namespace existe
if kubectl get namespace dev > /dev/null 2>&1; then
    check "Namespace 'dev' existe"
    kubectl get namespace dev -o jsonpath='{.metadata.name}' > /dev/null 2>&1
else
    echo -e "${RED}❌ Namespace 'dev' no existe${NC}"
    ((FAILED++))
fi

# Verificar ResourceQuota
if kubectl get resourcequota -n dev > /dev/null 2>&1; then
    check "ResourceQuota existe en namespace 'dev'"
    echo -e "${BLUE}   Detalles:${NC}"
    kubectl get resourcequota -n dev -o wide
else
    echo -e "${RED}❌ ResourceQuota no existe en namespace 'dev'${NC}"
    ((FAILED++))
fi

# Verificar LimitRange
if kubectl get limitrange -n dev > /dev/null 2>&1; then
    check "LimitRange existe en namespace 'dev'"
    echo -e "${BLUE}   Detalles:${NC}"
    kubectl get limitrange -n dev -o wide
else
    echo -e "${RED}❌ LimitRange no existe en namespace 'dev'${NC}"
    ((FAILED++))
fi

# Verificar NetworkPolicy
if kubectl get networkpolicy -n dev > /dev/null 2>&1; then
    check "NetworkPolicy existe en namespace 'dev'"
    echo -e "${BLUE}   Detalles:${NC}"
    kubectl get networkpolicy -n dev -o wide
else
    echo -e "${RED}❌ NetworkPolicy no existe en namespace 'dev'${NC}"
    ((FAILED++))
fi

echo ""

# ===== Verificación GCP GKE - Namespace 'prod' =====
echo -e "${BLUE}📦 Verificando namespace 'prod' en GCP GKE...${NC}"
echo ""

# Obtener credenciales de GCP GKE
gcloud container clusters get-credentials "$GCP_CLUSTER_NAME" \
  --zone "$GCP_ZONE" \
  --project "$GCP_PROJECT_ID" > /dev/null 2>&1

# Verificar namespace existe
if kubectl get namespace prod > /dev/null 2>&1; then
    check "Namespace 'prod' existe"
    kubectl get namespace prod -o jsonpath='{.metadata.name}' > /dev/null 2>&1
else
    echo -e "${RED}❌ Namespace 'prod' no existe${NC}"
    ((FAILED++))
fi

# Verificar ResourceQuota
if kubectl get resourcequota -n prod > /dev/null 2>&1; then
    check "ResourceQuota existe en namespace 'prod'"
    echo -e "${BLUE}   Detalles:${NC}"
    kubectl get resourcequota -n prod -o wide
else
    echo -e "${RED}❌ ResourceQuota no existe en namespace 'prod'${NC}"
    ((FAILED++))
fi

# Verificar LimitRange
if kubectl get limitrange -n prod > /dev/null 2>&1; then
    check "LimitRange existe en namespace 'prod'"
    echo -e "${BLUE}   Detalles:${NC}"
    kubectl get limitrange -n prod -o wide
else
    echo -e "${RED}❌ LimitRange no existe en namespace 'prod'${NC}"
    ((FAILED++))
fi

# Verificar NetworkPolicy
if kubectl get networkpolicy -n prod > /dev/null 2>&1; then
    check "NetworkPolicy existe en namespace 'prod'"
    echo -e "${BLUE}   Detalles:${NC}"
    kubectl get networkpolicy -n prod -o wide
else
    echo -e "${RED}❌ NetworkPolicy no existe en namespace 'prod'${NC}"
    ((FAILED++))
fi

echo ""

# ===== Verificación Terraform State =====
echo -e "${BLUE}🔧 Verificando estado de Terraform...${NC}"
echo ""

cd "$(dirname "$0")/.."

# Verificar que los namespaces están en el estado
if terraform state list | grep -q "module.namespace_dev.kubernetes_namespace.namespace"; then
    check "Namespace 'dev' está en el estado de Terraform"
else
    echo -e "${YELLOW}⚠️  Namespace 'dev' no está en el estado de Terraform${NC}"
    ((FAILED++))
fi

if terraform state list | grep -q "module.namespace_prod.*kubernetes_namespace.namespace"; then
    check "Namespace 'prod' está en el estado de Terraform"
else
    echo -e "${YELLOW}⚠️  Namespace 'prod' no está en el estado de Terraform${NC}"
    ((FAILED++))
fi

# Verificar que las políticas están en el estado
if terraform state list | grep -q "module.namespace_dev.kubernetes_resource_quota.quota"; then
    check "ResourceQuota de 'dev' está en el estado de Terraform"
else
    echo -e "${YELLOW}⚠️  ResourceQuota de 'dev' no está en el estado de Terraform${NC}"
    ((FAILED++))
fi

if terraform state list | grep -q "module.namespace_prod.*kubernetes_resource_quota.quota"; then
    check "ResourceQuota de 'prod' está en el estado de Terraform"
else
    echo -e "${YELLOW}⚠️  ResourceQuota de 'prod' no está en el estado de Terraform${NC}"
    ((FAILED++))
fi

echo ""

# ===== Resumen =====
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Resumen de Verificación${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Verificaciones exitosas: $PASSED${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}❌ Verificaciones fallidas: $FAILED${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Algunas verificaciones fallaron. Revisa los errores arriba.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Todas las verificaciones pasaron${NC}"
    echo ""
    echo -e "${GREEN}🎉 HU6 verificada exitosamente${NC}"
    exit 0
fi



