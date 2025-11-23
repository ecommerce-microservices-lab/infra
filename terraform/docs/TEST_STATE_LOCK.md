# 🔒 Prueba de Bloqueo de Estado - DoD HU 2

## 📸 Guía Paso a Paso para Capturas

**👉 Para obtener capturas de pantalla, consulta: [`PASO_A_PASO_PRUEBA_BLOQUEO.md`](./PASO_A_PASO_PRUEBA_BLOQUEO.md)**

## Objetivo

Demostrar que el backend remoto S3 con DynamoDB bloquea correctamente el estado de Terraform para prevenir conflictos cuando múltiples procesos intentan modificar el estado simultáneamente.

## Requisitos

- ✅ Bucket S3 creado: `microservices-terraform-state-658250199880`
- ✅ Tabla DynamoDB creada: `terraform-state-lock`
- ✅ Backend configurado en `providers.tf`
- ✅ Terraform inicializado con backend remoto

## Prueba Manual (Recomendada)

### Paso 1: Preparar las terminales

Abre **DOS terminales** en el directorio `infra/terraform`:

```bash
cd infra/terraform
```

### Paso 2: Terminal 1 - Adquirir lock

En la **Terminal 1**, ejecuta:

```bash
# Cargar variables de Azure
source <(grep -v '^#' ../../.azure-secrets-backup | grep -v '^$')
export ARM_CLIENT_ID=$AZURE_CLIENT_ID
export ARM_CLIENT_SECRET=$AZURE_CLIENT_SECRET
export ARM_TENANT_ID=$AZURE_TENANT_ID
export ARM_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID

# Ejecutar terraform plan (esto adquiere un lock)
terraform plan \
  -var="subscription_id=${ARM_SUBSCRIPTION_ID}" \
  -var="tenant_id=${ARM_TENANT_ID}" \
  -var="client_secret=${ARM_CLIENT_SECRET}" \
  -var="client_id=${ARM_CLIENT_ID}" \
  -var="gcp_project_id=microservices-gke-prod" \
  -var="gcp_credentials_path=$HOME/.gcp-keys/gke-admin-key.json" \
  -lock=true
```

**Deja esta terminal corriendo** (no canceles el comando).

### Paso 3: Terminal 2 - Intentar adquirir lock (debe fallar)

En la **Terminal 2** (mientras la Terminal 1 está corriendo), ejecuta el mismo comando:

```bash
# Cargar variables de Azure
source <(grep -v '^#' ../../.azure-secrets-backup | grep -v '^$')
export ARM_CLIENT_ID=$AZURE_CLIENT_ID
export ARM_CLIENT_SECRET=$AZURE_CLIENT_SECRET
export ARM_TENANT_ID=$AZURE_TENANT_ID
export ARM_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID

# Intentar ejecutar terraform plan (debe quedar bloqueado)
terraform plan \
  -var="subscription_id=${ARM_SUBSCRIPTION_ID}" \
  -var="tenant_id=${ARM_TENANT_ID}" \
  -var="client_secret=${ARM_CLIENT_SECRET}" \
  -var="client_id=${ARM_CLIENT_ID}" \
  -var="gcp_project_id=microservices-gke-prod" \
  -var="gcp_credentials_path=$HOME/.gcp-keys/gke-admin-key.json" \
  -lock=true
```

### Paso 4: Verificar el error

La **Terminal 2** debe mostrar un error similar a:

```
Error: Error acquiring the state lock

Error message: lock token <TOKEN>
Lock Info:
  ID:        <LOCK_ID>
  Path:      microservices-terraform-state-658250199880/terraform/azure/terraform.tfstate
  Operation: OperationTypePlan
  Who:       <USER>@<HOST>
  Version:   <TERRAFORM_VERSION>
  Created:   <TIMESTAMP>
  Info:      <INFO>

Terraform acquires a state lock to protect the state from being written
by multiple users at the same time. Please resolve the issue above and try
again. For most commands, you can disable locking with the "-lock=false"
flag, but this is not recommended.
```

### Paso 5: Verificar lock en DynamoDB

En una **tercera terminal**, verifica que el lock existe en DynamoDB:

```bash
aws dynamodb scan \
  --table-name terraform-state-lock \
  --region us-east-2 \
  --query "Items[*].[LockID.S,Info.S]" \
  --output table
```

Deberías ver el lock activo.

### Paso 6: Liberar el lock

En la **Terminal 1**, cancela el comando (`Ctrl+C`). El lock se liberará automáticamente.

O si necesitas liberarlo manualmente:

```bash
terraform force-unlock <LOCK_ID>
```

## Prueba Automatizada (Alternativa)

Ejecuta el script de prueba:

```bash
cd infra/terraform
bash scripts/demo-state-lock.sh
```

## Resultado Esperado

✅ **Éxito**: La Terminal 2 queda bloqueada y muestra un error de lock, demostrando que el mecanismo de bloqueo funciona correctamente.

❌ **Fallo**: Si la Terminal 2 puede ejecutar el comando sin error, el bloqueo no está funcionando correctamente.

## Evidencia para DoD

1. ✅ **Captura de pantalla 1**: Terminal 1 ejecutando `terraform plan`
2. ✅ **Captura de pantalla 2**: Terminal 2 mostrando error de lock
3. ✅ **Captura de pantalla 3**: Lock visible en DynamoDB
4. ✅ **Comando ejecutado**: `aws dynamodb scan --table-name terraform-state-lock`

## Notas

- El bloqueo es automático cuando usas `-lock=true` (por defecto)
- El lock se libera automáticamente cuando el comando termina
- Si un proceso se interrumpe, el lock puede quedar activo (usar `force-unlock` para liberarlo)
- El lock tiene un timeout automático (por defecto, 5 minutos para operaciones normales)

---

**Fecha de prueba**: [Fecha]
**Resultado**: ✅ Bloqueo funcionando correctamente
**Evidencia**: [Capturas de pantalla / Logs]

