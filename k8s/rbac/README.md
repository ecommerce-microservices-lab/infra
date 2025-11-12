# 🔐 RBAC - ServiceAccounts, Roles y RoleBindings

## 📋 Estructura

Este directorio contiene los manifiestos RBAC para aplicar el **Principio de Mínimo Privilegio** a todos los microservicios.

### Servicios con RBAC:
1. `api-gateway`
2. `cloud-config`
3. `service-discovery`
4. `user-service`
5. `product-service`
6. `order-service`
7. `payment-service`
8. `shipping-service`
9. `favourite-service`
10. `proxy-client`

## 🎯 Permisos Mínimos Necesarios

Cada servicio necesita:
- **ConfigMaps**: `get`, `list` (para `common-environment-variables`)
- **Secrets**: `get` (para `mysql-secret` y otros secrets específicos)
- **Services**: `get`, `list` (para service discovery con Eureka)

## 📁 Organización

Los manifiestos están organizados por servicio:
```
rbac/
  ├── api-gateway/
  │   ├── serviceaccount.yaml
  │   ├── role.yaml
  │   └── rolebinding.yaml
  ├── cloud-config/
  │   └── ...
  └── ...
```

## 🚀 Aplicación

Aplicar en cada namespace (dev, stage, prod):
```bash
kubectl apply -f infra/k8s/rbac/<service>/ -n <namespace>
```

