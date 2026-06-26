# ms-catalogo

Microservicio para la gestión del catálogo de productos de Madam Tusan.

- **Stack**: Serverless Framework v4, Python 3.12, DynamoDB.
- **Tabla DynamoDB**: `productos-{stage}` (PK: `tenant_id`, SK: `producto_id`)
- **Autenticación**: Endpoints protegidos mediante Cognito Authorizer (`ms-auth`).
- **Tenant por defecto**: `madam-tusan`

### Endpoints
- `GET /productos` - Listar productos.
- `GET /productos/{producto_id}` - Buscar producto.
- `POST /productos` - Crear producto.
- `PUT /productos/{producto_id}` - Modificar producto.
- `DELETE /productos/{producto_id}` - Eliminar producto.
