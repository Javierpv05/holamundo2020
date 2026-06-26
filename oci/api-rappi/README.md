# API Rappi Simulator - OCI Integration

Este proyecto implementa un API Gateway en OCI que actúa como un simulador de Rappi. Provee dos rutas principales que se conectan con tu backend existente en AWS y con una función serverless en OCI.

## Archivos del Proyecto

- `function/func.py`: Código Python de la Oracle Function `guardar-estado`. Recibe JSON, lo procesa y genera logs.
- `function/requirements.txt`: Dependencias de Python (FDK de Oracle).
- `function/func.yaml`: Configuración de Fn Project para construir y desplegar la función.
- `api-gateway.yaml`: Representación declarativa en YAML de las rutas del API Gateway (para referencia).
- `deploy.sh`: Script bash automatizado e idempotente que despliega toda la infraestructura (App, Función, Gateway, Deployment).

## Requisitos Previos

Para ejecutar el despliegue asegúrate de tener:
1. **OCI CLI** instalado y configurado (`~/.oci/config` con tu perfil configurado).
2. **Fn CLI** instalado y configurado apuntando a tu OCI Registry.
3. Una **VCN con una Subnet pública** existente en tu compartimiento Root.
4. **Docker** ejecutándose y logueado en tu OCI Registry (necesario para `fn deploy`).

## Cómo Desplegar

1. Abre tu terminal y navega hasta esta carpeta:
   ```bash
   cd /home/javier/Escritorio/UTEC-CICLO-IV/CLOUD-COMPUTING/proyectos/proyecto-final-pedidos/oci/api-rappi
   ```
2. Ejecuta el script:
   ```bash
   ./deploy.sh
   ```

El script creará automáticamente (o actualizará si ya existen) la aplicación Fn, la función, el Gateway y el Deployment. 

## Dónde obtener la URL final y cómo usarla

Al finalizar el script, verás en la terminal un recuadro similar a este con tu URL pública:

```text
#########################################################
Despliegue finalizado exitosamente.
URL Base de tu API Gateway: https://<gw-id>.apigateway.us-chicago-1.oci.customer-oci.com/rappi

Prueba las rutas con cURL:
1. Redirección hacia AWS:
   curl -X POST https://.../rappi/pedidos -H 'Content-Type: application/json' -d '{"pedido": 123}'

2. Invocación de Oracle Function (Guardar Estado):
   curl -X POST https://.../rappi/estado -H 'Content-Type: application/json' -d '{"pedido_id": "999", "estado": "ENTREGADO"}'
#########################################################
```

**Uso en AWS**:
Copia la URL `https://<gw-id>.../rappi/pedidos` o `https://<gw-id>.../rappi/estado` y configúrala como Endpoint HTTP en tu microservicio o Step Functions en AWS, dependiendo de la simulación que estés probando.
