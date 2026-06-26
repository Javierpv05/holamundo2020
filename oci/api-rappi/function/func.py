import io
import json
import logging
# pyrefly: ignore [missing-import]
from fdk import response

def handler(ctx, data: io.BytesIO = None):
    """
    Función de OCI para simular la recepción del estado de un pedido en Rappi.
    Recibe un JSON con 'pedido_id' y 'estado', y lo imprime en los logs.
    """
    try:
        # Intentar parsear el body entrante
        body = json.loads(data.getvalue()) if data else {}
        pedido_id = body.get("pedido_id", "Desconocido")
        estado = body.get("estado", "Desconocido")
        
        # Registrar en OCI Logging
        logger = logging.getLogger()
        logger.info(f"Rappi Simulator - Se recibió actualización. Pedido_ID: {pedido_id}, Estado: {estado}")
        
        # Responder 200 OK
        return response.Response(
            ctx, 
            response_data=json.dumps({"status": "success", "message": "Estado recibido correctamente por Rappi Simulator"}),
            headers={"Content-Type": "application/json"}
        )
    except Exception as ex:
        # Manejo de errores
        logging.getLogger().error(f"Error procesando solicitud: {str(ex)}")
        return response.Response(
            ctx, 
            response_data=json.dumps({"status": "error", "message": str(ex)}),
            headers={"Content-Type": "application/json"},
            status_code=400
        )
