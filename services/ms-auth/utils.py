import json
import decimal


class DecimalEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, decimal.Decimal):
            return float(o)
        return super(DecimalEncoder, self).default(o)


def build_response(status_code, body):
    """
    Construye una respuesta HTTP consistente con headers CORS.
    """
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Credentials": True,
        },
        "body": json.dumps(body, cls=DecimalEncoder),
    }


def log_event(level, message, data=None):
    """
    Registra un log estructurado en JSON para CloudWatch.
    """
    log_entry = {"level": level, "message": message}
    if data is not None:
        log_entry["data"] = data
    print(json.dumps(log_entry, cls=DecimalEncoder))


def get_claims(event):
    """
    Extrae los claims del JWT desde el contexto del authorizer de API Gateway.
    Retorna el dict de claims o None si no hay authorizer activo.
    """
    try:
        return event["requestContext"]["authorizer"]["claims"]
    except (KeyError, TypeError):
        return None
