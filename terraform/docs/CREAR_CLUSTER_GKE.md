# 🚀 Guía: Crear Cluster GKE con Terraform

## 📋 Resumen de lo que se Creará

### Recursos a Crear:
1. **VPC**: `microservices-cluster-gke-prod-vpc`
2. **Subnet**: `microservices-cluster-gke-prod-subnet` (10.0.0.0/24)
3. **Cluster GKE**: `microservices-cluster-gke-prod`
4. **Node Pool**: `microservices-cluster-gke-prod-node-pool`
   - 2 nodos iniciales
   - Autoscaling: 1-3 nodos
   - Máquina: `e2-medium` (2 vCPU, 4 GB RAM)
   - Disco: 20 GB

### ⏱️ Tiempo Estimado:
- **Creación del cluster**: 5-10 minutos
- **Total**: ~10-15 minutos

### 💰 Costos Estimados (GCP Free Tier):
- **Cluster GKE**: $0.10/hora (clusters gestionados)
- **Nodos e2-medium**: ~$0.067/hora por nodo × 2 = ~$0.134/hora
- **Total aproximado**: ~$0.23/hora (~$5.50/día si está corriendo 24/7)
- **Con Free Tier de $300 USD**: ~54 días de uso continuo

**⚠️ IMPORTANTE**: Puedes **detener el cluster** cuando no lo uses para ahorrar costos (solo pagas por los nodos cuando están corriendo).

---

## 🚀 Paso 1: Verificar Configuración

### Variables Necesarias:
- ✅ `gcp_project_id`: `microservices-gke-prod`
- ✅ `gcp_region`: `us-central1`
- ✅ `gcp_zone`: `us-central1-a`
- ✅ `gcp_credentials_path`: `~/.gcp-keys/gke-admin-key.json`

### Verificar Credenciales:
```bash
# Activar Service Account
gcloud auth activate-service-account --key-file=$HOME/.gcp-keys/gke-admin-key.json

# Verificar proyecto
gcloud config get-value project
# Debe mostrar: microservices-gke-prod
```

---

## 🚀 Paso 2: Ejecutar Terraform Plan

```bash
cd infra/terraform

# Cargar variables de Azure (necesarias para AKS)
source <(grep -v '^#' ../../.azure-secrets-backup | grep -v '^$')
export ARM_CLIENT_ID=$AZURE_CLIENT_ID
export ARM_CLIENT_SECRET=$AZURE_CLIENT_SECRET
export ARM_TENANT_ID=$AZURE_TENANT_ID
export ARM_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID

# Ejecutar plan
terraform plan \
  -var="subscription_id=${ARM_SUBSCRIPTION_ID}" \
  -var="tenant_id=${ARM_TENANT_ID}" \
  -var="client_secret=${ARM_CLIENT_SECRET}" \
  -var="client_id=${ARM_CLIENT_ID}" \
  -var="gcp_project_id=microservices-gke-prod" \
  -var="gcp_credentials_path=$HOME/.gcp-keys/gke-admin-key.json"
```

**Resultado esperado**: `Plan: 4 to add, 1 to change, 0 to destroy`

---

## 🚀 Paso 3: Crear el Cluster GKE

```bash
# Aplicar cambios (crear cluster)
terraform apply \
  -var="subscription_id=${ARM_SUBSCRIPTION_ID}" \
  -var="tenant_id=${ARM_TENANT_ID}" \
  -var="client_secret=${ARM_CLIENT_SECRET}" \
  -var="client_id=${ARM_CLIENT_ID}" \
  -var="gcp_project_id=microservices-gke-prod" \
  -var="gcp_credentials_path=$HOME/.gcp-keys/gke-admin-key.json" \
  -auto-approve
```

**⏱️ Tiempo**: 10-15 minutos

---

## 🚀 Paso 4: Verificar el Cluster

```bash
# Obtener credenciales de GKE
gcloud container clusters get-credentials microservices-cluster-gke-prod \
  --zone us-central1-a \
  --project microservices-gke-prod

# Verificar nodos
kubectl get nodes

# Verificar que el cluster está funcionando
kubectl cluster-info
```

---

## 🚀 Paso 5: Crear Namespace `prod`

```bash
# Crear namespace prod
kubectl create namespace prod

# Verificar
kubectl get namespaces
```

---

## ✅ Verificación Final

### Comandos de Verificación:

```bash
# 1. Ver cluster en GCP Console
gcloud container clusters list

# 2. Ver nodos
kubectl get nodes -o wide

# 3. Ver información del cluster
gcloud container clusters describe microservices-cluster-gke-prod \
  --zone us-central1-a \
  --project microservices-gke-prod

# 4. Ver outputs de Terraform
terraform output
```

---

## 🛑 Detener el Cluster (Para Ahorrar Costos)

```bash
# Detener el cluster (detiene los nodos, pero mantiene la configuración)
gcloud container clusters resize microservices-cluster-gke-prod \
  --num-nodes 0 \
  --zone us-central1-a \
  --project microservices-gke-prod

# O eliminar completamente el cluster
terraform destroy \
  -var="subscription_id=${ARM_SUBSCRIPTION_ID}" \
  -var="tenant_id=${ARM_TENANT_ID}" \
  -var="client_secret=${ARM_CLIENT_SECRET}" \
  -var="client_id=${ARM_CLIENT_ID}" \
  -var="gcp_project_id=microservices-gke-prod" \
  -var="gcp_credentials_path=$HOME/.gcp-keys/gke-admin-key.json" \
  -target=module.gke_prod
```

---

## 📊 Recursos Creados

### VPC y Red:
- **VPC**: `microservices-cluster-gke-prod-vpc`
- **Subnet**: `microservices-cluster-gke-prod-subnet`
  - CIDR: `10.0.0.0/24`
  - Pods: `10.1.0.0/16`
  - Services: `10.2.0.0/16`

### Cluster GKE:
- **Nombre**: `microservices-cluster-gke-prod`
- **Zona**: `us-central1-a`
- **Release Channel**: `REGULAR`
- **Logging**: Habilitado
- **Monitoring**: Habilitado

### Node Pool:
- **Nombre**: `microservices-cluster-gke-prod-node-pool`
- **Nodos**: 2 (autoscaling: 1-3)
- **Máquina**: `e2-medium` (2 vCPU, 4 GB RAM)
- **Disco**: 20 GB (pd-standard)
- **Auto-repair**: Habilitado
- **Auto-upgrade**: Habilitado

---

## 🔧 Troubleshooting

### Error: "Quota exceeded"
- Verifica cuotas en GCP Console
- Reduce el número de nodos o el tipo de máquina

### Error: "Permission denied"
- Verifica que el Service Account tiene los roles necesarios
- Verifica que las APIs están habilitadas

### Error: "Resource already exists"
- El recurso ya existe, verifica en GCP Console
- Usa `terraform import` si es necesario

---

## 📚 Referencias

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Terraform GKE Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)
- [GCP Pricing Calculator](https://cloud.google.com/products/calculator)

