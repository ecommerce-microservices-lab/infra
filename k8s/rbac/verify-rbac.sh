#!/bin/bash
# Script para verificar RBAC en un namespace

set -e

NAMESPACE=${1:-prod}

if [ -z "$NAMESPACE" ]; then
  echo "❌ Error: Debes especificar un namespace"
  echo "Uso: ./verify-rbac.sh <namespace>"
  exit 1
fi

echo "🔐 Verificando RBAC en namespace: $NAMESPACE"
echo ""

SERVICES=("api-gateway" "cloud-config" "service-discovery" "user-service" "product-service" "order-service" "payment-service" "shipping-service" "favourite-service" "proxy-client")

# Verificar ServiceAccounts
echo "📋 ServiceAccounts:"
kubectl get serviceaccounts -n $NAMESPACE 2>/dev/null | grep -E "$(IFS='|'; echo "${SERVICES[*]}")" || echo "⚠️  No se encontraron ServiceAccounts"
echo ""

# Verificar Roles
echo "📋 Roles:"
kubectl get roles -n $NAMESPACE 2>/dev/null | grep -E "$(IFS='|'; echo "${SERVICES[*]}")" || echo "⚠️  No se encontraron Roles"
echo ""

# Verificar RoleBindings
echo "📋 RoleBindings:"
kubectl get rolebindings -n $NAMESPACE 2>/dev/null | grep -E "$(IFS='|'; echo "${SERVICES[*]}")" || echo "⚠️  No se encontraron RoleBindings"
echo ""

# Verificar Deployments
echo "📋 ServiceAccounts en Deployments:"
for SERVICE in "${SERVICES[@]}"; do
  SA=$(kubectl get deployment $SERVICE -n $NAMESPACE -o jsonpath='{.spec.template.spec.serviceAccountName}' 2>/dev/null || echo "N/A")
  if [ "$SA" == "$SERVICE" ]; then
    echo "✅ $SERVICE: $SA"
  else
    echo "❌ $SERVICE: $SA (esperado: $SERVICE)"
  fi
done
echo ""

# Verificar permisos con auth can-i
echo "🧪 Verificando permisos con kubectl auth can-i:"
echo ""
for SERVICE in "${SERVICES[@]}"; do
  echo "📦 $SERVICE:"
  
  # Verificar permisos permitidos (con nombres específicos de recursos)
  CAN_GET_CM=$(kubectl auth can-i get configmaps/common-environment-variables --as=system:serviceaccount:$NAMESPACE:$SERVICE -n $NAMESPACE 2>/dev/null || echo "no")
  CAN_GET_SECRET=$(kubectl auth can-i get secrets/mysql-secret --as=system:serviceaccount:$NAMESPACE:$SERVICE -n $NAMESPACE 2>/dev/null || echo "no")
  CAN_LIST_SVC=$(kubectl auth can-i list services --as=system:serviceaccount:$NAMESPACE:$SERVICE -n $NAMESPACE 2>/dev/null || echo "no")
  
  # Verificar permisos denegados
  CAN_CREATE_POD=$(kubectl auth can-i create pods --as=system:serviceaccount:$NAMESPACE:$SERVICE -n $NAMESPACE 2>/dev/null || echo "no")
  CAN_DELETE_CM=$(kubectl auth can-i delete configmaps --as=system:serviceaccount:$NAMESPACE:$SERVICE -n $NAMESPACE 2>/dev/null || echo "no")
  
  if [ "$CAN_GET_CM" == "yes" ] && [ "$CAN_GET_SECRET" == "yes" ] && [ "$CAN_LIST_SVC" == "yes" ] && [ "$CAN_CREATE_POD" == "no" ] && [ "$CAN_DELETE_CM" == "no" ]; then
    echo "  ✅ Permisos correctos"
    echo "     - get configmaps/common-environment-variables: $CAN_GET_CM"
    echo "     - get secrets/mysql-secret: $CAN_GET_SECRET"
    echo "     - list services: $CAN_LIST_SVC"
    echo "     - create pods (denegado): $CAN_CREATE_POD"
  else
    echo "  ⚠️  Permisos:"
    echo "     - get configmaps/common-environment-variables: $CAN_GET_CM"
    echo "     - get secrets/mysql-secret: $CAN_GET_SECRET"
    echo "     - list services: $CAN_LIST_SVC"
    echo "     - create pods (denegado): $CAN_CREATE_POD"
    echo "     - delete configmaps (denegado): $CAN_DELETE_CM"
  fi
done

echo ""
echo "✅ Verificación completada"

