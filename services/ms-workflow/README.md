# ms-workflow

Microservicio para la orquestación del flujo de pedidos de Madam Tusan mediante AWS Step Functions.

- **Stack**: Serverless Framework v4, Python 3.12, AWS Step Functions, DynamoDB.
- **Tabla DynamoDB**: `pedido_pasos-{stage}` (PK: `tenant_id`, SK: `paso_id`)
- **Autenticación**: Endpoints protegidos mediante Cognito Authorizer (`ms-auth`).
- **Tenant por defecto**: `madam-tusan`

### Step Functions y Patrón Wait for Callback

La máquina de estados `WorkflowPedido` orquesta el ciclo de vida del pedido:
1. **Inicio**: Una regla de EventBridge escucha el evento `PedidoCreado` desde `ms-pedidos` y lanza la ejecución.
2. **Estados Humanos (Cocina, Despacho, Reparto)**:
   - Utilizan el patrón **Wait for Callback with Task Token** (`waitForTaskToken`).
   - Al entrar al estado, Step Functions invoca una Lambda (ej. `cocinarTask`), pasándole un token único (`taskToken`).
   - La Lambda guarda este token en la tabla `pedido_pasos` con estado `PENDIENTE` y actualiza el estado del pedido en la tabla `pedidos`.
   - La ejecución de Step Functions **se pausa** esperando confirmación.
3. **Reanudación**:
   - Cuando el operador humano termina su trabajo, envía una petición a `POST /pasos/avanzar`.
   - Este endpoint recupera el `taskToken` guardado en DynamoDB y llama a `sfn.send_task_success(taskToken)`.
   - Step Functions recibe la señal y avanza al siguiente paso del flujo.
4. **Fin (Entregado)**:
   - Al finalizar el reparto, se ejecuta una tarea automática `entregarTask` que marca el pedido como `ENTREGADO` y el flujo termina con éxito.

### Endpoints
- `POST /pasos/avanzar` - Avanzar al siguiente paso del workflow confirmando la acción humana.
