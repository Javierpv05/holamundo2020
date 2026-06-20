"""
repartir_task.py — Invocada por Step Functions (waitForTaskToken).

Idéntica en estructura a cocinar_task.py, pero para el paso REPARTO.
Guarda el token en DynamoDB y pausa el flujo hasta que el operador confirme.
"""
import json
import os
import uuid
from datetime import datetime, timezone

import boto3

dynamodb = boto3.resource("dynamodb")
tabla = dynamodb.Table(os.environ["TABLA_PASOS"])

PASO = "REPARTO"

CORS_HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
}


def handler(event, context):
    try:
        pedido = event.get("pedido", event)
        task_token = event.get("taskToken")

        tenant_id = pedido.get("tenant_id", "taco-bell")
        pedido_id = pedido.get("pedido_id", "desconocido")

        paso_item = {
            "tenant_id": tenant_id,
            "paso_id": str(uuid.uuid4()),
            "pedido_id": pedido_id,
            "paso": PASO,
            "estado": "PENDIENTE",
            "task_token": task_token,
            "fecha_inicio": datetime.now(timezone.utc).isoformat(),
        }

        tabla.put_item(Item=paso_item)

        return {
            "statusCode": 200,
            "mensaje": f"Paso {PASO} registrado. Esperando confirmación del operador.",
            "tenant_id": tenant_id,
            "pedido_id": pedido_id,
            "paso": PASO,
        }

    except Exception as e:
        raise RuntimeError(f"Error en tarea {PASO}: {str(e)}")
