# 📸 Paso a Paso: Prueba de Bloqueo de Estado - Para Capturas

## Objetivo

Obtener capturas de pantalla que demuestren que el bloqueo de estado funciona correctamente.

## Requisitos Previos

- ✅ AWS CLI configurado
- ✅ Terraform inicializado con backend S3
- ✅ Variables de Azure disponibles

## Preparación

### 1. Abrir 3 terminales

Abre **3 terminales** en tu editor o terminal favorito:
- **Terminal 1**: Para ejecutar `terraform plan` (adquirirá el lock)
- **Terminal 2**: Para intentar ejecutar `terraform plan` (debe fallar)
- **Terminal 3**: Para verificar locks en DynamoDB

### 2. Navegar al directorio

En **TODAS las terminales**, ejecuta:

```bash
cd /Users/santiago/Documents/learning/devops-learning-hub/tests-release/infra/terraform
```

---

## Paso 1: Preparar Variables de Azure

En **Terminal 1 y Terminal 2**, carga las variables de Azure:

```bash
# Cargar variables de Azure
source <(grep -v '^#' ../../.azure-secrets-backup | grep -v '^$')
export ARM_CLIENT_ID=$AZURE_CLIENT_ID
export ARM_CLIENT_SECRET=$AZURE_CLIENT_SECRET
export ARM_TENANT_ID=$AZURE_TENANT_ID
export ARM_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID

# Variables de GCP
export GCP_PROJECT_ID=microservices-gke-prod
export GCP_CREDENTIALS_PATH=$HOME/.gcp-keys/gke-admin-key.json
```

**✅ Captura 1**: Toma captura de las variables cargadas (opcional, pero útil)

---

## Paso 2: Terminal 1 - Adquirir Lock

En la **Terminal 1**, ejecuta:

```bash
terraform plan \
  -var="subscription_id=${ARM_SUBSCRIPTION_ID}" \
  -var="tenant_id=${ARM_TENANT_ID}" \
  -var="client_secret=${ARM_CLIENT_SECRET}" \
  -var="client_id=${ARM_CLIENT_ID}" \
  -var="gcp_project_id=${GCP_PROJECT_ID}" \
  -var="gcp_credentials_path=${GCP_CREDENTIALS_PATH}" \
  -lock=true
```

**⚠️ IMPORTANTE**: Deja esta terminal corriendo. NO la canceles todavía.

**✅ Captura 2**: Toma captura de la Terminal 1 mostrando que `terraform plan` está ejecutándose (puede mostrar "Refreshing state..." o "Planning...").

---

## Paso 3: Terminal 3 - Verificar Lock en DynamoDB

En la **Terminal 3**, verifica que el lock existe en DynamoDB:

```bash
aws dynamodb scan \
  --table-name terraform-state-lock \
  --region us-east-2 \
  --query "Items[*].[LockID.S,Info.S]" \
  --output table
```

Deberías ver el lock activo.

**✅ Captura 3**: Toma captura de la Terminal 3 mostrando el lock en DynamoDB.

---

## Paso 4: Terminal 2 - Intentar Adquirir Lock (Debe Fallar)

En la **Terminal 2** (mientras la Terminal 1 está corriendo), ejecuta el mismo comando:

```bash
terraform plan \
  -var="subscription_id=${ARM_SUBSCRIPTION_ID}" \
  -var="tenant_id=${ARM_TENANT_ID}" \
  -var="client_secret=${ARM_CLIENT_SECRET}" \
  -var="client_id=${ARM_CLIENT_ID}" \
  -var="gcp_project_id=${GCP_PROJECT_ID}" \
  -var="gcp_credentials_path=${GCP_CREDENTIALS_PATH}" \
  -lock=true
```

**✅ Captura 4**: Toma captura de la Terminal 2 mostrando el error de lock. Debe mostrar algo como:

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

**Esta es la captura más importante** - demuestra que el bloqueo funciona.

---

## Paso 5: Terminal 1 - Cancelar o Esperar

En la **Terminal 1**, puedes:
- **Opción A**: Esperar a que `terraform plan` termine (puede tardar varios minutos)
- **Opción B**: Cancelar con `Ctrl+C` (el lock se liberará automáticamente)

**✅ Captura 5** (Opcional): Toma captura de la Terminal 1 después de cancelar, mostrando que el lock se liberó.

---

## Paso 6: Terminal 3 - Verificar que el Lock se Liberó

En la **Terminal 3**, verifica nuevamente:

```bash
aws dynamodb scan \
  --table-name terraform-state-lock \
  --region us-east-2 \
  --query "Items[*].[LockID.S,Info.S]" \
  --output table
```

Si cancelaste la Terminal 1, el lock debería haberse liberado (la tabla estará vacía o solo tendrá el lock-md5).

**✅ Captura 6** (Opcional): Toma captura mostrando que el lock se liberó.

---

## Paso 7: Verificar Estado en S3

En la **Terminal 3**, verifica que el estado está en S3:

```bash
aws s3 ls s3://microservices-terraform-state-658250199880/terraform/azure/
```

Deberías ver el archivo `terraform.tfstate`.

**✅ Captura 7**: Toma captura mostrando el estado en S3.

---

## Resumen de Capturas Necesarias

### Capturas Obligatorias (DoD)

1. **✅ Captura 2**: Terminal 1 ejecutando `terraform plan` (lock adquirido)
2. **✅ Captura 3**: Terminal 3 mostrando lock en DynamoDB
3. **✅ Captura 4**: Terminal 2 mostrando error de lock (LA MÁS IMPORTANTE)

### Capturas Opcionales (Pero Recomendadas)

4. **✅ Captura 7**: Estado en S3
5. **✅ Captura 6**: Lock liberado en DynamoDB (después de cancelar Terminal 1)

---

## Consejos para las Capturas

1. **Terminal 1 y 2**: Muestra ambas terminales lado a lado para demostrar el bloqueo simultáneo
2. **Terminal 3**: Muestra el lock en DynamoDB claramente
3. **Error de lock**: Asegúrate de que el mensaje de error completo sea visible
4. **Timestamp**: Incluye la hora en las capturas para demostrar que son simultáneas

---

## Verificación Final

Después de tomar las capturas, verifica que tienes:

- ✅ Captura de Terminal 1 ejecutando `terraform plan`
- ✅ Captura de Terminal 2 mostrando error de lock
- ✅ Captura de lock en DynamoDB
- ✅ Captura de estado en S3 (opcional pero recomendado)

---

## Troubleshooting

### Si Terminal 2 no muestra error de lock

- Verifica que Terminal 1 todavía está corriendo
- Espera unos segundos y vuelve a intentar en Terminal 2
- Verifica que ambas terminales están en el mismo directorio

### Si el lock no aparece en DynamoDB

- Espera unos segundos (puede haber un delay)
- Verifica que la tabla existe: `aws dynamodb describe-table --table-name terraform-state-lock --region us-east-2`

### Si Terminal 1 termina muy rápido

- Esto es normal si no hay cambios que planificar
- El lock se adquiere y libera rápidamente
- Intenta ejecutar `terraform apply` en lugar de `plan` para que dure más tiempo

---

## Comandos de Referencia Rápida

### Terminal 1 y 2 (Cargar variables)
```bash
cd /Users/santiago/Documents/learning/devops-learning-hub/tests-release/infra/terraform
source <(grep -v '^#' ../../.azure-secrets-backup | grep -v '^$')
export ARM_CLIENT_ID=$AZURE_CLIENT_ID
export ARM_CLIENT_SECRET=$AZURE_CLIENT_SECRET
export ARM_TENANT_ID=$AZURE_TENANT_ID
export ARM_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID
export GCP_PROJECT_ID=microservices-gke-prod
export GCP_CREDENTIALS_PATH=$HOME/.gcp-keys/gke-admin-key.json
```

### Terminal 1 y 2 (Ejecutar terraform plan)
```bash
terraform plan \
  -var="subscription_id=${ARM_SUBSCRIPTION_ID}" \
  -var="tenant_id=${ARM_TENANT_ID}" \
  -var="client_secret=${ARM_CLIENT_SECRET}" \
  -var="client_id=${ARM_CLIENT_ID}" \
  -var="gcp_project_id=${GCP_PROJECT_ID}" \
  -var="gcp_credentials_path=${GCP_CREDENTIALS_PATH}" \
  -lock=true
```

### Terminal 3 (Verificar lock en DynamoDB)
```bash
aws dynamodb scan --table-name terraform-state-lock --region us-east-2 --query "Items[*].[LockID.S,Info.S]" --output table
```

### Terminal 3 (Verificar estado en S3)
```bash
aws s3 ls s3://microservices-terraform-state-658250199880/terraform/azure/
```

---

**¡Listo! Sigue estos pasos y toma las capturas necesarias para demostrar que el bloqueo funciona correctamente.**

