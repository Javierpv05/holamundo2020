"""
avanzar_paso.py — Endpoint público: POST /pasos/avanzar

El operador o frontend llama a este endpoint cuando completa un paso.
El handler:
  1. Valida el body.
  2. Busca en DynamoDB el paso PENDIENTE del pedido para obtener el task_token.
  3. Llama a send_task_success para reanudar la Step Function.
  4. Actualiza el estado del paso en DynamoDB a COMPLETADO.

Body esperado:
{
    "tenant_id": "taco-bell",
    "pedido_id": "abc123",
    "paso": "COCINA" | "DESPACHO" | "REPARTO",
    "usuario": "chef-juan",
    "observacion": "Listo en 10 min"   (opcional)
}
"""
import json
import os
import uuid
from datetime import datetime, timezone

import boto3
from boto3.dynamodb.conditions import Key, Attr

dynamodb = boto3.resource("dynamodb")
tabla = dynamodb.Table(os.environ["TABLA_PASOS"])
sfn_client = boto3.client("stepfunctions")

PASOS_VALIDOS = {"COCINA", "DESPACHO", "REPARTO"}

CORS_HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
}


def handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")

        tenant_id = body.get("tenant_id", "taco-bell")
        pedido_id = body.get("pedido_id")
        paso = (body.get("paso") or "").upper()
        usuario = body.get("usuario", "operador")
        observacion = body.get("observacion", "")

        # ── Validaciones ──────────────────────────────────────────────────
        if not pedido_id:
            return _error(400, "El campo 'pedido_id' es obligatorio")

        if paso not in PASOS_VALIDOS:
            return _error(
                400,
                f"Paso inválido '{paso}'. Válidos: {', '.join(sorted(PASOS_VALIDOS))}",
            )

        # ── Buscar el task_token del paso PENDIENTE en DynamoDB ───────────
        respuesta = tabla.query(
            KeyConditionExpression=Key("tenant_id").eq(tenant_id),
            FilterExpression=Attr("pedido_id").eq(pedido_id)
            & Attr("paso").eq(paso)
            & Attr("estado").eq("PENDIENTE"),
        )

        items = respuesta.get("Items", [])

        if not items:
            return _error(
                404,
                f"No se encontró un paso '{paso}' PENDIENTE para el pedido '{pedido_id}'",
            )

        # Tomamos el más reciente si hay varios (ordenados por fecha_inicio desc)
        paso_pendiente = sorted(items, key=lambda x: x.get("fecha_inicio", ""), reverse=True)[0]
        task_token = paso_pendiente.get("task_token")
        paso_id = paso_pendiente["paso_id"]

        if not task_token:
            return _error(500, "El paso pendiente no tiene task_token registrado")

        fecha_fin = datetime.now(timezone.utc).isoformat()

        # ── Actualizar estado del paso a COMPLETADO en DynamoDB ───────────
        tabla.update_item(
            Key={"tenant_id": tenant_id, "paso_id": paso_id},
            UpdateExpression=(
                "SET #estado = :completado, usuario = :usuario, "
                "observacion = :obs, fecha_fin = :fecha_fin"
            ),
            ExpressionAttributeNames={"#estado": "estado"},
            ExpressionAttributeValues={
                ":completado": "COMPLETADO",
                ":usuario": usuario,
                ":obs": observacion,
                ":fecha_fin": fecha_fin,
            },
        )

        # ── Notificar a Step Functions para reanudar el flujo ─────────────
        output = json.dumps(
            {
                "paso": paso,
                "pedido_id": pedido_id,
                "tenant_id": tenant_id,
                "usuario": usuario,
                "observacion": observacion,
                "completado_en": fecha_fin,
            }
        )

        sfn_client.send_task_success(taskToken=task_token, output=output)

        return {
            "statusCode": 200,
            "headers": CORS_HEADERS,
            "body": json.dumps(
                {
                    "mensaje": f"Paso '{paso}' completado. Workflow avanzado.",
                    "pedido_id": pedido_id,
                    "tenant_id": tenant_id,
                    "paso": paso,
                    "usuario": usuario,
                    "completado_en": fecha_fin,
                }
            ),
        }

    except sfn_client.exceptions.TaskDoesNotExist:
        return _error(404, "El task_token no corresponde a ninguna tarea activa en Step Functions")

    except sfn_client.exceptions.TaskTimedOut:
        return _error(410, "El task_token ha expirado. La tarea ya no está activa")

    except Exception as e:
        return _error(500, f"Error al avanzar el paso: {str(e)}")


def _error(status_code: int, mensaje: str) -> dict:
    return {
        "statusCode": status_code,
        "headers": CORS_HEADERS,
        "body": json.dumps({"error": mensaje}),
    }
