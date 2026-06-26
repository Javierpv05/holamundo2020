# Sistema de Gestión de Pedidos — Proyecto Final Cloud Computing

Plataforma multi-tenant de pedidos de comida (Madam Tusan) con arquitectura serverless basada en eventos, desplegada en AWS (principal) y OCI (componente multi-nube).

## Arquitectura

```
Cliente → API Gateway (HTTP API) → Lambda (Python 3.12)
                                        ↓
                                   DynamoDB (multi-tenant: PK=tenant_id)
                                        ↓
                                   EventBridge → Step Functions / Notificaciones
                                        ↓ (multi-nube)
                                   OCI Functions / Oracle DB
```

## Microservicios

| Servicio       | Descripción                              | Estado     |
|----------------|------------------------------------------|------------|
| ms-catalogo    | CRUD de productos por tenant             | Listo      |
| ms-pedidos     | Creación y consulta de pedidos           | Listo      |
| ms-workflow    | Orquestación del flujo de estados        | Listo      |
| ms-auth        | Autenticación con Cognito y usuarios     | Listo      |

## Despliegue

**Requisitos:** Node v20, Serverless Framework v4, credenciales AWS configuradas con acceso al LabRole.

```bash
# Desplegar ms-catalogo en stage dev
cd services/ms-catalogo
serverless deploy --stage dev

# Desplegar en producción
serverless deploy --stage prod
```

## Stack

- **Cloud principal:** AWS (Lambda, DynamoDB, API Gateway HTTP API, EventBridge)
- **Multi-nube:** OCI (Oracle Cloud Infrastructure)
- **Runtime:** Python 3.12
- **IaC:** Serverless Framework v4
- **IAM:** LabRole (`arn:aws:iam::413507650058:role/LabRole`)
