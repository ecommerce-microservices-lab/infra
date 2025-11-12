#!/bin/bash
# Script para aplicar RBAC en un namespace específico

set -e

NAMESPACE=${1:-prod}

if [ -z "$NAMESPACE" ]; then
  echo "❌ Error: Debes especificar un namespace"
  echo "Uso: ./apply-rbac.sh <namespace>"
  echo "Ejemplo: ./apply-rbac.sh prod"
  exit 1
fi

echo "🔐 Aplicando RBAC en namespace: $NAMESPACE"
echo ""

# Lista de servicios
SERVICES=("api-gateway" "cloud-config" "service-discovery" "user-service" "product-service" "order-service" "payment-service" "shipping-service" "favourite-service" "proxy-client")

# Aplicar RBAC para cada servicio
for SERVICE in "${SERVICES[@]}"; do
  echo "📦 Aplicando RBAC para $SERVICE..."
  
  # Actualizar namespace en los manifiestos temporalmente
  sed "s/namespace: prod/namespace: $NAMESPACE/g" "infra/k8s/rbac/$SERVICE/serviceaccount.yaml" | kubectl apply -f -
  sed "s/namespace: prod/namespace: $NAMESPACE/g" "infra/k8s/rbac/$SERVICE/role.yaml" | kubectl apply -f -
  sed "s/namespace: prod/namespace: $NAMESPACE/g" "infra/k8s/rbac/$SERVICE/rolebinding.yaml" | kubectl apply -f -
  
  echo "✅ RBAC aplicado para $SERVICE"
done

echo ""
echo "✅ RBAC aplicado exitosamente en namespace: $NAMESPACE"
echo ""
echo "📋 Verificar ServiceAccounts:"
kubectl get serviceaccounts -n $NAMESPACE | grep -E "api-gateway|cloud-config|service-discovery|user-service|product-service|order-service|payment-service|shipping-service|favourite-service|proxy-client"
echo ""
echo "📋 Verificar Roles:"
kubectl get roles -n $NAMESPACE | grep -E "api-gateway|cloud-config|service-discovery|user-service|product-service|order-service|payment-service|shipping-service|favourite-service|proxy-client"
echo ""
echo "📋 Verificar RoleBindings:"
kubectl get rolebindings -n $NAMESPACE | grep -E "api-gateway|cloud-config|service-discovery|user-service|product-service|order-service|payment-service|shipping-service|favourite-service|proxy-client"

