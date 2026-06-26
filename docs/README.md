# Documentación — Sistema de Gestión de Pedidos

## Diseño de Tablas DynamoDB

---

### Tabla `productos-{stage}` (ms-catalogo)

| Atributo      | Tipo | Rol                  | Descripción                          |
|---------------|------|----------------------|--------------------------------------|
| `tenant_id`   | S    | Partition Key (PK)   | Identificador del tenant (restaurante)|
| `producto_id` | S    | Sort Key (SK)        | UUID generado al crear el producto   |
| `nombre`      | S    | Atributo             | Nombre del producto                  |
| `precio`      | N    | Atributo             | Precio en soles/dólares              |
| `descripcion` | S    | Atributo             | Descripción del producto             |
| `disponible`  | BOOL | Atributo             | Si el producto está activo           |

**Patrón de acceso principal:** Query por `tenant_id` para listar todo el catálogo de un tenant.
**Patrón secundario:** GetItem por `tenant_id + producto_id` para detalle de un producto.

---

### Tabla `pedidos-{stage}` (ms-pedidos)

| Atributo        | Tipo | Rol                    | Descripción                                     |
|-----------------|------|------------------------|-------------------------------------------------|
| `tenant_id`     | S    | Partition Key (PK)     | Identificador del tenant                        |
| `pedido_id`     | S    | Sort Key (SK)          | UUID generado al crear el pedido                |
| `estado_actual` | S    | Atributo               | RECIBIDO / PREPARANDO / LISTO / ENTREGADO       |
| `tenant_estado` | S    | GSI PK (índice PorEstado) | Compuesto: `"tenant_id#estado_actual"`       |
| `fecha_creacion`| S    | GSI SK (índice PorEstado) | ISO 8601, permite ordenar cronológicamente   |
| `cliente`       | S    | Atributo               | Nombre o ID del cliente                         |
| `items`         | L    | Atributo               | Lista de productos pedidos                      |
| `total`         | N    | Atributo               | Monto total del pedido                          |
| `origen`        | S    | Atributo               | Canal: "web", "app", "presencial"               |

#### GSI: `PorEstado`
- **PK:** `tenant_estado` — e.g. `"taco-bell#RECIBIDO"`
- **SK:** `fecha_creacion` — orden cronológico dentro del estado
- **Proyección:** ALL
- **Uso:** Listar todos los pedidos de un tenant filtrados por estado, ordenados por fecha.

---

### Tabla `pedido_pasos-{stage}` (ms-workflow)

| Atributo      | Tipo | Rol                | Descripción                                           |
|---------------|------|--------------------|-------------------------------------------------------|
| `tenant_id`   | S    | Partition Key (PK) | Identificador del tenant                              |
| `paso_id`     | S    | Sort Key (SK)      | UUID generado por cada paso registrado                |
| `pedido_id`   | S    | Atributo           | Referencia al pedido al que pertenece el paso         |
| `paso`        | S    | Atributo           | Nombre del paso: RECIBIDO, PREPARANDO, LISTO, etc.    |
| `responsable` | S    | Atributo           | ID o nombre del empleado que completó el paso         |
| `estado`      | S    | Atributo           | Estado del paso: "COMPLETADO"                         |
| `fecha_fin`   | S    | Atributo           | ISO 8601 — momento en que se completó el paso         |

**Patrón de acceso:** Query por `tenant_id` para ver todos los pasos de todos los pedidos de un tenant. Para filtrar por pedido específico se usa un FilterExpression sobre `pedido_id`.

**TODO:** Agregar GSI `PorPedido` con PK=`pedido_id` para consultar el historial de pasos de un pedido concreto sin scan completo.

---

## EventBridge

### Bus `pedidos-bus-{stage}` (ms-pedidos)

| Campo         | Valor                          |
|---------------|--------------------------------|
| `Source`      | `pedidos.app`                  |
| `DetailType`  | `PedidoCreado`                 |
| `Detail`      | `{ tenant_id, pedido_id }`     |
| `EventBusName`| `pedidos-bus-{stage}`          |

**Uso actual:** ms-workflow tiene suscrita una regla EventBridge sobre este bus para iniciar la máquina de estados de Step Functions automáticamente al recibir el evento `PedidoCreado`.

---

## Flujo Step Functions (ms-workflow)

El siguiente diagrama muestra la máquina de estados que orquesta los pedidos, utilizando el patrón **Wait for Callback**:

```mermaid
stateDiagram-v2
    [*] --> Cocina : PedidoCreado (EventBridge)
    
    state Cocina {
        [*] --> cocinar_task (Lambda)
        cocinar_task (Lambda) --> Espera_Cocina : Guarda taskToken en DynamoDB
        Espera_Cocina --> [*] : Operador hace POST /pasos/avanzar
    }
    
    Cocina --> Despacho : sfn.send_task_success()
    
    state Despacho {
        [*] --> despachar_task (Lambda)
        despachar_task (Lambda) --> Espera_Despacho : Guarda taskToken
        Espera_Despacho --> [*] : Operador hace POST /pasos/avanzar
    }
    
    Despacho --> Reparto : sfn.send_task_success()
    
    state Reparto {
        [*] --> repartir_task (Lambda)
        repartir_task (Lambda) --> Espera_Reparto : Guarda taskToken
        Espera_Reparto --> [*] : Operador hace POST /pasos/avanzar
    }
    
    Reparto --> Entregado : sfn.send_task_success()
    
    state Entregado {
        [*] --> entregar_task (Lambda)
        entregar_task (Lambda) --> [*] : Actualiza pedidos a ENTREGADO
    }
    
    Entregado --> PedidoEntregado
    PedidoEntregado --> [*]
```

---

## TODOs pendientes

- [x] Integración Step Functions en ms-workflow (`send_task_success`)
- [x] Regla EventBridge `PedidoCreado` → Step Functions en ms-workflow
- [ ] GSI `PorPedido` en tabla `pedido_pasos` para historial por pedido
- [x] Cognito User Pools para autenticación multi-tenant
- [ ] OCI: Functions + Oracle DB como nube secundaria
- [ ] Frontend web-cliente y web-trabajadores
