#!/bin/bash
# Script para instalar NGINX Ingress Controller, cert-manager y configurar TLS/HTTPS
# Uso: ./install-tls.sh [DOMAIN] [EMAIL]
#
# Ejemplo:
# ./install-tls.sh api.microservices.example.com santiesleo17@gmail.com

set -e

DOMAIN="${1:-api.microservices.example.com}"
EMAIL="${2:-santiesleo17@gmail.com}"

echo "🔐 Instalando TLS/HTTPS para API Gateway"
echo "Dominio: $DOMAIN"
echo "Email: $EMAIL"
echo ""

# Verificar que kubectl está configurado
if ! kubectl cluster-info &>/dev/null; then
    echo "❌ Error: kubectl no está configurado o no puede conectarse al cluster"
    exit 1
fi

echo "📦 Paso 1: Instalando NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

echo "⏳ Esperando que NGINX Ingress Controller esté listo..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

echo "✅ NGINX Ingress Controller instalado"
echo ""

echo "📦 Paso 2: Instalando cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

echo "⏳ Esperando que cert-manager esté listo..."
kubectl wait --namespace cert-manager \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=cert-manager \
  --timeout=300s

echo "✅ cert-manager instalado"
echo ""

echo "📦 Paso 3: Creando ClusterIssuer de Let's Encrypt..."
# Actualizar el email en el ClusterIssuer
sed "s/santiesleo17@gmail.com/$EMAIL/g" clusterissuer-letsencrypt.yaml | kubectl apply -f -

echo "⏳ Esperando que ClusterIssuer esté listo..."
sleep 10

echo "✅ ClusterIssuer creado"
echo ""

echo "📦 Paso 4: Creando Ingress con TLS..."
# Actualizar el dominio en el Ingress
sed "s/api.microservices.example.com/$DOMAIN/g" ../prod/api-gateway-ingress.yaml | kubectl apply -f -

echo "✅ Ingress creado"
echo ""

echo "📋 Verificando estado..."
echo ""
echo "NGINX Ingress Controller:"
kubectl get pods -n ingress-nginx
echo ""
echo "cert-manager:"
kubectl get pods -n cert-manager
echo ""
echo "ClusterIssuer:"
kubectl get clusterissuer
echo ""
echo "Ingress:"
kubectl get ingress -n prod
echo ""

echo "⏳ Esperando que el certificado TLS sea emitido (esto puede tomar 1-5 minutos)..."
kubectl wait --namespace prod \
  --for=condition=ready certificate \
  --selector=app=api-gateway \
  --timeout=600s || echo "⚠️  El certificado puede tardar más en emitirse. Verifica con: kubectl get certificate -n prod"

echo ""
echo "✅ Instalación completada!"
echo ""
echo "📝 Próximos pasos:"
echo "1. Obtén la IP del LoadBalancer: kubectl get svc -n ingress-nginx ingress-nginx-controller"
echo "2. Configura el DNS para apuntar $DOMAIN a esa IP"
echo "3. Verifica el certificado: kubectl get certificate -n prod"
echo "4. Prueba el acceso HTTPS: curl -I https://$DOMAIN"
echo "5. Valida en SSL Labs: https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN"

