# Configuración de TLS/HTTPS para API Gateway

Esta carpeta contiene los manifiestos y scripts necesarios para implementar TLS/HTTPS en el API Gateway usando NGINX Ingress Controller y cert-manager con Let's Encrypt.

## 📋 Requisitos

### Opción 1: Con Dominio Real (Recomendado para Producción)

1. **Dominio registrado**: Necesitas un dominio real
   - 💡 **Opciones gratuitas con GitHub Student Developer Pack:**
     - **Namecheap**: 1 año de dominio `.me` + certificado SSL gratis
     - **Name.com**: Dominio gratuito con extensiones `.live`, `.studio`, `.software`, `.app`, `.dev`
     - **.TECH DOMAINS**: 1 año de dominio `.tech` gratis
   - O cualquier otro proveedor de dominios (GoDaddy, Google Domains, etc.)
2. **Acceso a DNS**: Para configurar registros A que apunten a la IP del LoadBalancer
3. **Email válido**: Para recibir notificaciones de Let's Encrypt

### Configuración de Dominios

**No necesitas múltiples dominios**, puedes usar **subdominios** del mismo dominio:

**Ejemplo con dominio `.me` (Namecheap):**
- **API Gateway**: `api.tudominio.me` → Backend/REST API
- **Frontend**: `app.tudominio.me` → Frontend (proxy-client)

**Ejemplo con dominio `.dev` (Name.com):**
- **API Gateway**: `api.tudominio.dev` → Backend/REST API
- **Frontend**: `app.tudominio.dev` → Frontend (proxy-client)

**Ejemplo con dominio `.tech` (.TECH DOMAINS):**
- **API Gateway**: `api.tudominio.tech` → Backend/REST API
- **Frontend**: `app.tudominio.tech` → Frontend (proxy-client)

**Ventajas de usar subdominios:**
- ✅ Un solo dominio registrado
- ✅ Certificados TLS separados (más seguro)
- ✅ Fácil de gestionar
- ✅ Mejor organización
- ✅ Funciona perfectamente con Let's Encrypt

### Opción 2: Sin Dominio (Solo Documentación)

Puedes documentar el proceso completo sin ejecutarlo. Los manifiestos están listos para cuando tengas un dominio.

## 🚀 Instalación

### Paso 1: Instalar NGINX Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Verificar instalación
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

### Paso 2: Obtener la IP del LoadBalancer

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

Anota la IP EXTERNAL-IP. Esta será la IP a la que debe apuntar tu dominio.

### Paso 3: Configurar DNS

Si tienes un dominio real, configura **registros A** en tu proveedor de DNS para cada subdominio:

**Para API Gateway:**
```
Tipo: A
Nombre: api
Valor: <IP_EXTERNAL-IP_del_LoadBalancer>
TTL: 300
```

**Para Frontend (proxy-client):**
```
Tipo: A
Nombre: app (o www, o @ para el dominio raíz)
Valor: <IP_EXTERNAL-IP_del_LoadBalancer>  (misma IP)
TTL: 300
```

**Ejemplo:** Si tu dominio es `microservices.com` y la IP es `35.202.48.194`:
- `api.microservices.com` → `35.202.48.194` (API Gateway)
- `app.microservices.com` → `35.202.48.194` (Frontend)

**Nota:** Ambos subdominios apuntan a la misma IP del LoadBalancer del Ingress Controller. El Ingress se encarga de enrutar según el hostname.

### Paso 4: Instalar cert-manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# Verificar instalación
kubectl get pods -n cert-manager
```

### Paso 5: Crear ClusterIssuer

Edita `clusterissuer-letsencrypt.yaml` y actualiza el email:

```bash
# Editar el email en el archivo
vim clusterissuer-letsencrypt.yaml

# Aplicar
kubectl apply -f clusterissuer-letsencrypt.yaml

# Verificar
kubectl get clusterissuer
```

### Paso 6: Actualizar y Aplicar los Ingress

Edita ambos archivos de Ingress y reemplaza los dominios de ejemplo:

**Para API Gateway:**
```bash
# Editar el dominio del API Gateway
vim ../prod/api-gateway-ingress.yaml
# Cambiar: api.microservices.example.com → api.microservices.com

# Aplicar
kubectl apply -f ../prod/api-gateway-ingress.yaml
```

**Para Frontend (proxy-client):**
```bash
# Editar el dominio del Frontend
vim ../prod/proxy-client-ingress.yaml
# Cambiar: app.microservices.example.com → app.microservices.com

# Aplicar
kubectl apply -f ../prod/proxy-client-ingress.yaml
```

**Verificar ambos Ingress:**
```bash
kubectl get ingress -n prod
kubectl describe ingress api-gateway-ingress -n prod
kubectl describe ingress proxy-client-ingress -n prod
```

### Paso 7: Verificar los Certificados

```bash
# Ver el estado de todos los certificados
kubectl get certificate -n prod

# Ver detalles de cada certificado
kubectl describe certificate api-gateway-tls-cert -n prod
kubectl describe certificate proxy-client-tls-cert -n prod

# Ver los eventos de cert-manager
kubectl get events -n prod --sort-by='.lastTimestamp' | grep certificate
```

Los certificados pueden tardar 1-5 minutos en emitirse. Una vez listos, verás algo como:

```
NAME                    READY   SECRET              AGE
api-gateway-tls-cert    True    api-gateway-tls     2m
proxy-client-tls-cert   True    proxy-client-tls    2m
```

## 🧪 Pruebas

### Probar HTTPS

**API Gateway:**
```bash
# Obtener el dominio del API Gateway
API_HOST=$(kubectl get ingress api-gateway-ingress -n prod -o jsonpath='{.spec.rules[0].host}')

# Probar HTTPS
curl -I https://$API_HOST

# Probar que HTTP redirige a HTTPS
curl -I http://$API_HOST
```

**Frontend:**
```bash
# Obtener el dominio del Frontend
FRONTEND_HOST=$(kubectl get ingress proxy-client-ingress -n prod -o jsonpath='{.spec.rules[0].host}')

# Probar HTTPS
curl -I https://$FRONTEND_HOST

# Probar que HTTP redirige a HTTPS
curl -I http://$FRONTEND_HOST
```

### Validar en SSL Labs

1. Ve a https://www.ssllabs.com/ssltest/
2. Ingresa cada dominio:
   - `https://api.microservices.com` (API Gateway)
   - `https://app.microservices.com` (Frontend)
3. Espera el análisis (puede tardar unos minutos)
4. Verifica que ambos obtengan una calificación **A** o superior

## 📝 Configuración Actual

- **Service Type**: `ClusterIP` (cambió de `LoadBalancer`) - Solo para `prod`
- **Ingress Controller**: NGINX Ingress Controller
- **Certificate Manager**: cert-manager v1.13.3
- **Certificate Authority**: Let's Encrypt (producción)
- **Security Headers**: HSTS, X-Frame-Options, X-Content-Type-Options, etc.
- **Dominios configurados**:
  - `api.microservices.com` → API Gateway (puerto 8080)
  - `app.microservices.com` → Frontend/Proxy-Client (puerto 8900)

## 🔒 Security Headers Configurados

- **HSTS**: HTTP Strict Transport Security (max-age: 1 año)
- **X-Frame-Options**: DENY (previene clickjacking)
- **X-Content-Type-Options**: nosniff (previene MIME sniffing)
- **X-XSS-Protection**: 1; mode=block
- **Referrer-Policy**: strict-origin-when-cross-origin

## ⚠️ Notas Importantes

1. **Solo para producción (GCP GKE)**: Los ambientes `dev` y `stage` en Azure AKS mantienen `LoadBalancer`
2. **Dominio requerido**: Let's Encrypt requiere un dominio real para emitir certificados
3. **Renovación automática**: cert-manager renueva automáticamente los certificados antes de expirar
4. **Límites de Let's Encrypt**: 
   - 50 certificados por dominio registrado por semana
   - 5 duplicados por semana

## 🐛 Troubleshooting

### El certificado no se emite

```bash
# Ver logs de cert-manager
kubectl logs -n cert-manager -l app=cert-manager

# Ver eventos del certificado
kubectl describe certificate api-gateway-tls-cert -n prod

# Verificar que el DNS apunta correctamente
nslookup api.microservices.com
```

### El Ingress no tiene IP

```bash
# Verificar que el LoadBalancer del Ingress Controller tenga IP
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Si no tiene IP, espera unos minutos (GCP puede tardar)
```

### Error 404 en el Ingress

```bash
# Verificar que el Service api-gateway existe y tiene endpoints
kubectl get svc api-gateway -n prod
kubectl get endpoints api-gateway -n prod

# Verificar que los pods están corriendo
kubectl get pods -n prod -l io.kompose.service=api-gateway
```

## 📚 Referencias

- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt](https://letsencrypt.org/)
- [SSL Labs](https://www.ssllabs.com/ssltest/)

