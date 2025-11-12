#!/bin/bash

# Script para crear el bucket S3 y la tabla DynamoDB para el backend de Terraform
# Ejecutar: bash scripts/create-s3-backend.sh

set -e

BUCKET_NAME="microservices-terraform-state-658250199880"
REGION="us-east-2"
DYNAMODB_TABLE="terraform-state-lock"

echo "🚀 Creando backend remoto para Terraform en AWS S3..."

# Verificar que AWS CLI está instalado
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI no está instalado. Instálalo con: brew install awscli"
    exit 1
fi

# Verificar que AWS está configurado
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS CLI no está configurado. Ejecuta: aws configure"
    exit 1
fi

echo "✅ AWS CLI configurado correctamente"

# Crear bucket S3
echo "📦 Creando bucket S3: $BUCKET_NAME..."
if aws s3 ls "s3://$BUCKET_NAME" 2>&1 | grep -q 'NoSuchBucket'; then
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION"
    
    # Habilitar versionado
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled
    
    # Habilitar encriptación
    aws s3api put-bucket-encryption \
        --bucket "$BUCKET_NAME" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }'
    
    # Bloquear acceso público
    aws s3api put-public-access-block \
        --bucket "$BUCKET_NAME" \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    
    echo "✅ Bucket S3 creado exitosamente"
else
    echo "⚠️  El bucket $BUCKET_NAME ya existe"
fi

# Crear tabla DynamoDB para state locking
echo "🔒 Creando tabla DynamoDB para state locking: $DYNAMODB_TABLE..."
if ! aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" &> /dev/null; then
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$REGION"
    
    echo "⏳ Esperando a que la tabla esté activa..."
    aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region "$REGION"
    
    echo "✅ Tabla DynamoDB creada exitosamente"
else
    echo "⚠️  La tabla $DYNAMODB_TABLE ya existe"
fi

echo ""
echo "✅ Backend S3 configurado correctamente!"
echo ""
echo "📋 Información del backend:"
echo "   Bucket: $BUCKET_NAME"
echo "   Región: $REGION"
echo "   Tabla DynamoDB: $DYNAMODB_TABLE"
echo ""
echo "📝 Próximos pasos:"
echo "   1. Descomentar el bloque 'backend' en providers.tf (Azure) y backend.tf (GCP)"
echo "   2. Ejecutar: terraform init -reconfigure"
echo "   3. Ejecutar: terraform plan"
echo ""

