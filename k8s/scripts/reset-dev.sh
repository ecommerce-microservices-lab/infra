#!/bin/bash
# Reset rápido del entorno dev en AKS (sin borrar el namespace)
# Uso:
#   ./infra/k8s/scripts/reset-dev.sh
#
# Requisitos:
# - kubectl apuntando al cluster de Azure AKS (contexto microservices-cluster-prod)
# - Manifests en infra/k8s/base y infra/k8s/dev

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Reset rápido de entorno dev (AKS)${NC}"
echo "========================================"
echo ""

NAMESPACE="dev"

echo -e "${BLUE}1) Verificando contexto actual de kubectl...${NC}"
CURRENT_CTX=$(kubectl config current-context 2>/dev/null || true)
if [ -z "$CURRENT_CTX" ]; then
  echo -e "${RED}❌ kubectl no tiene contexto actual. Configura primero las credenciales de AKS.${NC}"
  exit 1
fi

echo -e "   Contexto actual: ${YELLOW}$CURRENT_CTX${NC}"
if [[ "$CURRENT_CTX" != *"microservices-cluster-prod"* ]]; then
  echo -e "${YELLOW}⚠️  Aviso: el contexto no parece ser el cluster de AKS (microservices-cluster-prod).${NC}"
  echo -e "${YELLOW}   Si no es intencional, ejecuta antes:${NC}"
  echo -e "     ${BLUE}kubectl config use-context microservices-cluster-prod${NC}"
  echo ""
fi

echo -e "${BLUE}2) Borrando MySQL en namespace '${NAMESPACE}'...${NC}"
kubectl delete deployment mysql -n "$NAMESPACE" --ignore-not-found
kubectl delete svc mysql-service -n "$NAMESPACE" --ignore-not-found
echo -e "${GREEN}   ✅ MySQL eliminado (si existía)${NC}"
echo ""

echo -e "${BLUE}3) Borrando pods de microservicios en '${NAMESPACE}'...${NC}"
kubectl delete pod -n "$NAMESPACE" -l io.kompose.service --ignore-not-found
echo -e "${GREEN}   ✅ Pods de microservicios eliminados${NC}"
echo ""

echo -e "${BLUE}4) Recreando MySQL y secrets base...${NC}"
kubectl apply -n "$NAMESPACE" -f infra/k8s/base/mysql-secret.yaml
kubectl apply -n "$NAMESPACE" -f infra/k8s/base/mysql.yaml
echo -e "${GREEN}   ✅ MySQL y secret aplicados${NC}"
echo ""

echo -e "${BLUE}5) Asegurando servicios core (cloud-config, service-discovery)...${NC}"
kubectl apply -n "$NAMESPACE" -f infra/k8s/base/cloud-config.yaml
kubectl apply -n "$NAMESPACE" -f infra/k8s/base/service-discovery.yaml
echo -e "${GREEN}   ✅ Core aplicado${NC}"
echo ""

echo -e "${BLUE}6) Aplicando manifests de dev...${NC}"
kubectl apply -n "$NAMESPACE" -f infra/k8s/dev/
echo -e "${GREEN}   ✅ Manifests de dev aplicados${NC}"
echo ""

echo -e "${BLUE}7) Esperando a que los pods arranquen (60s)...${NC}"
sleep 60

echo -e "${BLUE}8) Estado de pods en '${NAMESPACE}':${NC}"
kubectl get pods -n "$NAMESPACE"
echo ""

echo -e "${BLUE}9) Servicios registrados en Eureka (dev):${NC}"
if kubectl exec -n "$NAMESPACE" deployment/service-discovery -- \
  curl -s http://localhost:8761/eureka/apps >/tmp/eureka-apps.json 2>/dev/null; then
  grep -o '<name>[^<]*</name>' /tmp/eureka-apps.json | sed 's/<name>//;s/<\\/name>//' | sort -u || true
else
  echo -e "${YELLOW}⚠️  No se pudo consultar Eureka todavía (service-discovery puede seguir arrancando).${NC}"
fi

echo ""
echo -e "${GREEN}✅ Reset rápido de dev completado${NC}"


