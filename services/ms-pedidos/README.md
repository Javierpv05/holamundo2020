# ms-pedidos

Microservicio para la creación y gestión de pedidos de Madam Tusan.

- **Stack**: Serverless Framework v4, Python 3.12, DynamoDB, EventBridge.
- **Tabla DynamoDB**: `pedidos-{stage}` (PK: `tenant_id`, SK: `pedido_id`, GSI: `tenant_estado`)
- **EventBridge**: `pedidos-bus-{stage}`
- **Autenticación**: Endpoints protegidos mediante Cognito Authorizer (`ms-auth`).
- **Tenant por defecto**: `madam-tusan`

### Endpoints
- `POST /pedidos` - Crear nuevo pedido.
- `GET /pedidos` - Listar pedidos.
- `GET /pedidos/{pedido_id}` - Consultar estado de pedido.
- `GET /pedidos/estado/{estado}` - Listar pedidos por estado.
