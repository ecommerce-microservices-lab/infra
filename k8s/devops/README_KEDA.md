# KEDA - Kubernetes Event-Driven Autoscaling

## Descripción

KEDA es un componente de Kubernetes que permite escalar aplicaciones basándose en eventos externos o métricas personalizadas. Esta implementación configura KEDA para escalar automáticamente microservicios en producción basándose en diferentes triggers.

## Instalación

### Prerrequisitos

- Helm 3.x instalado
- Acceso al cluster de producción (GKE)
- Permisos para crear namespaces y CRDs

### Pasos de Instalación

1. **Instalar KEDA usando el script proporcionado:**

```bash
cd infra/k8s/devops
./keda-install.sh
```

O manualmente:

```bash
# Añadir Helm repo
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

# Crear namespace
kubectl create namespace keda-system

# Instalar KEDA
helm upgrade --install keda kedacore/keda \
  --namespace keda-system \
  --version 2.13.0 \
  --wait
```

2. **Verificar instalación:**

```bash
kubectl get pods -n keda-system
kubectl get crd | grep keda
```

Deberías ver:
- `keda-operator` pod corriendo
- CRDs: `scaledobjects.keda.sh`, `scaledjobs.keda.sh`, `triggerauthentications.keda.sh`

## Configuración de ScaledObjects

### Servicios Configurados

Se han configurado 3 servicios con diferentes triggers:

#### 1. **api-gateway** - Trigger: Prometheus (HTTP Request Rate)
- **Métrica**: `sum(rate(http_server_requests_seconds_count{service="api-gateway"}[1m]))`
- **Threshold**: 2 req/s
- **Rango**: 1-5 réplicas
- **Escala cuando**: El request rate supera 2 requests por segundo

#### 2. **order-service** - Trigger: Prometheus (CPU Usage)
- **Métrica**: `avg(process_cpu_usage{namespace="prod", service="order-service"}) * 100`
- **Threshold**: 70%
- **Rango**: 1-4 réplicas
- **Escala cuando**: El uso de CPU promedio supera el 70%

#### 3. **payment-service** - Trigger: Prometheus (Business Metrics)
- **Métrica**: `rate(completed_payments_total{service="payment-service"}[1m])`
- **Threshold**: 0.5 pagos/minuto
- **Rango**: 1-3 réplicas
- **Escala cuando**: La tasa de pagos completados supera 0.5 por minuto

### Aplicar ScaledObjects

```bash
kubectl apply -f infra/k8s/devops/keda-scaledobjects.yaml
```

### Verificar ScaledObjects

```bash
# Listar ScaledObjects
kubectl get scaledobjects -n prod

# Ver detalles de un ScaledObject
kubectl describe scaledobject api-gateway-scaler -n prod

# Ver HPA creado por KEDA
kubectl get hpa -n prod
```

## Pruebas

### Probar escalado de api-gateway

1. **Generar carga HTTP:**

```bash
# Generar carga HTTP (200 requests con delay de 0.1s)
for i in {1..200}; do
  curl -s https://api.santiesleo.dev/app/api/products > /dev/null
  sleep 0.1
done
```

2. **Monitorear escalado:**

```bash
# En otra terminal
watch kubectl get pods -n prod -l io.kompose.service=api-gateway
```

Deberías ver cómo el número de réplicas aumenta cuando la carga supera el threshold.

### Probar escalado de payment-service

1. **Crear múltiples pagos** (usando el flujo completo de checkout)
2. **Monitorear:**

```bash
watch kubectl get pods -n prod -l io.kompose.service=payment-service
```

### Ver métricas de KEDA

```bash
# Ver logs de KEDA operator
kubectl logs -n keda-system -l app=keda-operator --tail=50

# Ver métricas de escalado en Prometheus
# Query: keda_scaler_metrics_value
```

## Monitoreo

### Métricas de KEDA en Prometheus

KEDA expone métricas que puedes consultar en Prometheus:

- `keda_scaler_metrics_value` - Valor actual de la métrica
- `keda_scaler_metrics_errors` - Errores al obtener métricas
- `keda_scaler_active` - Estado del scaler (0=inactivo, 1=activo)

### Dashboards de Grafana

Puedes crear paneles en Grafana para monitorear:
- Número de réplicas actuales vs. deseadas
- Valores de métricas que disparan el escalado
- Eventos de escalado (up/down)

## Troubleshooting

### KEDA no escala los pods

1. **Verificar que KEDA está corriendo:**
```bash
kubectl get pods -n keda-system
```

2. **Verificar que el ScaledObject está activo:**
```bash
kubectl describe scaledobject <nombre> -n prod
```

3. **Verificar que Prometheus es accesible desde KEDA:**
```bash
kubectl exec -n keda-system <keda-operator-pod> -- wget -qO- http://prometheus.monitoring.svc.cluster.local:9090/api/v1/query?query=up
```

4. **Revisar logs de KEDA:**
```bash
kubectl logs -n keda-system -l app=keda-operator --tail=100
```

### Métricas no disponibles

Si las métricas de Prometheus no están disponibles:
- Verificar que Prometheus está scrapeando los servicios
- Verificar que las métricas existen en Prometheus: `http://prometheus.santiesleo.dev/graph`
- Ajustar la query en el ScaledObject si es necesario

## Referencias

- [KEDA Documentation](https://keda.sh/docs/)
- [KEDA ScaledObject Spec](https://keda.sh/docs/2.13/concepts/scaling-deployments/)
- [Prometheus Scaler](https://keda.sh/docs/2.13/scalers/prometheus/)

