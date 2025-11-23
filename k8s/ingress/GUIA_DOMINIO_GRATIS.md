# Guía: Configurar Dominio Gratis del GitHub Student Developer Pack

Esta guía te ayudará a configurar un dominio gratuito del GitHub Student Developer Pack para tu proyecto de microservicios.

## 🎓 Ofertas Disponibles

### 1. Namecheap
- **Oferta**: 1 año de dominio `.me` + certificado SSL gratis por 1 año
- **Ideal para**: Proyectos personales, portfolios
- **Ejemplo**: `microservices-api.me`, `microservices-app.me`

### 2. Name.com
- **Oferta**: Dominio gratuito con extensiones `.live`, `.studio`, `.software`, `.app`, `.dev`
- **Ideal para**: Proyectos de desarrollo (`.dev` es perfecto para APIs)
- **Ejemplo**: `microservices-api.dev`, `microservices-app.dev`

### 3. .TECH DOMAINS
- **Oferta**: 1 año de dominio `.tech` gratis
- **Ideal para**: Proyectos tecnológicos
- **Ejemplo**: `microservices-api.tech`, `microservices-app.tech`

## 🚀 Pasos para Configurar

### Paso 1: Obtener el Dominio Gratis

1. Ve a tu [GitHub Student Developer Pack](https://education.github.com/pack)
2. Busca la oferta de dominios (Namecheap, Name.com, o .TECH)
3. Activa la oferta y sigue las instrucciones para registrar tu dominio
4. Elige un nombre de dominio (ej: `microservices-api`)

### Paso 2: Configurar DNS

Una vez que tengas el dominio registrado, necesitas configurar los registros DNS:

#### En Namecheap:
1. Ve a tu cuenta de Namecheap
2. Selecciona tu dominio
3. Ve a "Advanced DNS"
4. Agrega registros A:

```
Tipo: A Record
Host: api
Value: <IP_del_LoadBalancer_del_Ingress>
TTL: Automatic (o 300)

Tipo: A Record
Host: app
Value: <IP_del_LoadBalancer_del_Ingress>  (misma IP)
TTL: Automatic (o 300)
```

#### En Name.com:
1. Ve a tu cuenta de Name.com
2. Selecciona tu dominio
3. Ve a "DNS Records"
4. Agrega registros A similares a los de arriba

#### En .TECH DOMAINS:
1. Ve a tu cuenta de .TECH
2. Configura los registros A de la misma manera

### Paso 3: Obtener la IP del LoadBalancer

```bash
# Conectar al cluster de GCP GKE
gcloud container clusters get-credentials microservices-cluster-gke-prod \
  --zone us-central1-a \
  --project microservices-gke-prod

# Obtener la IP del Ingress Controller
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Anota la IP EXTERNAL-IP
```

### Paso 4: Actualizar los Manifiestos de Ingress

Edita los archivos de Ingress con tu dominio real:

**`infra/k8s/prod/api-gateway-ingress.yaml`:**
```yaml
spec:
  rules:
    - host: api.tudominio.dev  # Cambiar por tu dominio real
      ...
  tls:
    - hosts:
        - api.tudominio.dev  # Cambiar por tu dominio real
```

**`infra/k8s/prod/proxy-client-ingress.yaml`:**
```yaml
spec:
  rules:
    - host: app.tudominio.dev  # Cambiar por tu dominio real
      ...
  tls:
    - hosts:
        - app.tudominio.dev  # Cambiar por tu dominio real
```

### Paso 5: Aplicar la Configuración

```bash
# Aplicar los Ingress actualizados
kubectl apply -f infra/k8s/prod/api-gateway-ingress.yaml
kubectl apply -f infra/k8s/prod/proxy-client-ingress.yaml

# Verificar
kubectl get ingress -n prod
```

### Paso 6: Esperar la Propagación DNS

Los cambios DNS pueden tardar:
- **TTL bajo (300s)**: 5-10 minutos
- **TTL alto**: Hasta 24-48 horas

Verifica la propagación:
```bash
# Verificar que el DNS apunta correctamente
nslookup api.tudominio.dev
nslookup app.tudominio.dev

# Deberías ver la IP del LoadBalancer
```

### Paso 7: Verificar los Certificados TLS

```bash
# Ver el estado de los certificados
kubectl get certificate -n prod

# Ver detalles
kubectl describe certificate api-gateway-tls-cert -n prod
kubectl describe certificate proxy-client-tls-cert -n prod
```

Los certificados de Let's Encrypt se emitirán automáticamente una vez que:
1. ✅ El DNS esté propagado
2. ✅ El Ingress esté configurado
3. ✅ cert-manager pueda validar el dominio

## 🧪 Pruebas

### Probar HTTPS

```bash
# API Gateway
curl -I https://api.tudominio.dev

# Frontend
curl -I https://app.tudominio.dev

# Verificar redirección HTTP → HTTPS
curl -I http://api.tudominio.dev
# Debería redirigir a HTTPS
```

### Validar en SSL Labs

1. Ve a https://www.ssllabs.com/ssltest/
2. Ingresa tu dominio: `https://api.tudominio.dev`
3. Espera el análisis
4. Verifica calificación **A** o superior

## 💡 Recomendaciones

### ¿Qué extensión elegir?

- **`.dev`**: Perfecto para proyectos de desarrollo, APIs
- **`.me`**: Ideal para proyectos personales
- **`.tech`**: Excelente para proyectos tecnológicos
- **`.app`**: Bueno para aplicaciones web

### Configuración Recomendada

```
Dominio base: microservices-api.dev (o .me, .tech)

Subdominios:
├── api.microservices-api.dev  → API Gateway
└── app.microservices-api.dev  → Frontend
```

O si prefieres un dominio más corto:

```
Dominio base: ms-api.dev

Subdominios:
├── api.ms-api.dev  → API Gateway
└── app.ms-api.dev  → Frontend
```

## ⚠️ Notas Importantes

1. **Dominios gratuitos**: Los dominios del Student Pack suelen ser por 1 año. Renueva antes de que expire.
2. **Let's Encrypt**: Funciona perfectamente con estos dominios gratuitos.
3. **Propagación DNS**: Puede tardar hasta 48 horas, pero normalmente es más rápido.
4. **Certificados SSL**: Namecheap ofrece un certificado SSL gratis, pero Let's Encrypt es más flexible y se renueva automáticamente.

## 🐛 Troubleshooting

### El DNS no resuelve

```bash
# Verificar desde diferentes ubicaciones
nslookup api.tudominio.dev
dig api.tudominio.dev

# Esperar más tiempo si acabas de configurarlo
```

### El certificado no se emite

```bash
# Ver logs de cert-manager
kubectl logs -n cert-manager -l app=cert-manager

# Ver eventos del certificado
kubectl describe certificate api-gateway-tls-cert -n prod

# Verificar que el DNS apunta correctamente
nslookup api.tudominio.dev
```

### Error 404 en el Ingress

```bash
# Verificar que los Services existen
kubectl get svc -n prod

# Verificar que los pods están corriendo
kubectl get pods -n prod

# Ver logs del Ingress Controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

## 📚 Referencias

- [GitHub Student Developer Pack](https://education.github.com/pack)
- [Namecheap Support](https://www.namecheap.com/support/)
- [Name.com Support](https://www.name.com/support)
- [.TECH DOMAINS Support](https://get.tech/support)

