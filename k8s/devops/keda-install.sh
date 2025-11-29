#!/bin/bash
# Script para instalar KEDA en el cluster de producción

set -e

echo "🚀 Instalando KEDA en el cluster..."

# Añadir el Helm repo de KEDA
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

# Crear namespace para KEDA si no existe
kubectl create namespace keda-system --dry-run=client -o yaml | kubectl apply -f -

# Instalar KEDA usando Helm
helm upgrade --install keda kedacore/keda \
  --namespace keda-system \
  --version 2.13.0 \
  --wait

echo "✅ KEDA instalado correctamente"
echo ""
echo "Verificar instalación:"
echo "  kubectl get pods -n keda-system"
echo "  kubectl get crd | grep keda"

