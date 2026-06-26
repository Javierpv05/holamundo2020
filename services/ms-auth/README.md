org: javierpariansullca
service: ms-auth

# ms-auth — Microservicio de Autenticación
# Grupo 5 · Madam Tusan · Proyecto Final Cloud Computing

## Descripción

Gestiona el registro, login y perfil de usuarios usando **Amazon Cognito** como proveedor
de identidad y **DynamoDB** como almacén de perfiles extendidos.

## Recursos desplegados

| Recurso | Nombre | Descripción |
|---|---|---|
| Cognito User Pool | `madamtusan-pool-{stage}` | Pool de usuarios con atributo custom `tenant_id` |
| Cognito App Client | `madamtusan-web-client-{stage}` | Cliente sin secreto para el frontend web |
| DynamoDB | `usuarios-{stage}` | Perfiles extendidos (PK=tenant_id, SK=user_id) |

## Tabla DynamoDB: `usuarios-{stage}`

| Atributo | Tipo | Rol | Descripción |
|---|---|---|---|
| `tenant_id` | String | Partition Key | Identificador del restaurante |
| `user_id` | String | Sort Key | UUID `sub` de Cognito |
| `email` | String | Atributo | Email del usuario |
| `nombre` | String | Atributo | Nombre completo |
| `rol` | String | Atributo | `cliente` o `trabajador` |
| `telefono` | String | Atributo | Teléfono de contacto |
| `confirmado` | Boolean | Atributo | Si el email fue verificado |

## Endpoints

| Método | Ruta | Auth | Descripción |
|---|---|---|---|
| POST | `/auth/registro` | Público | Registra un nuevo usuario |
| POST | `/auth/login` | Público | Inicia sesión, retorna JWT |
| GET | `/auth/usuario` | Cognito JWT | Obtiene perfil del usuario |
| PUT | `/auth/usuario` | Cognito JWT | Actualiza perfil del usuario |

## Despliegue

```bash
cd services/ms-auth
serverless deploy --stage dev
```

Tras el despliegue, anota estos valores de los Outputs de CloudFormation:
- `UserPoolId` → `VITE_COGNITO_USER_POOL_ID` en el .env del frontend
- `AppClientId` → `VITE_COGNITO_APP_CLIENT_ID` en el .env del frontend
- URL del API Gateway → `VITE_AUTH_API` en el .env del frontend

## Orden de despliegue

1. `ms-auth` (primero, exporta el User Pool ARN)
2. `ms-catalogo`
3. `ms-pedidos`
4. `ms-workflow`
