"""
login.py — POST /auth/login (público, sin authorizer)

Body esperado:
{
    "email":    "usuario@ejemplo.com",
    "password": "Pass1234"
}

Respuesta exitosa:
{
    "access_token":  "...",
    "id_token":      "...",
    "refresh_token": "...",
    "expires_in":    3600
}
"""
import json
import os
import boto3
from botocore.exceptions import ClientError
from utils import build_response, log_event

cognito = boto3.client("cognito-idp")
APP_CLIENT_ID = os.environ["APP_CLIENT_ID"]


def handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")

        email = body.get("email", "").strip().lower()
        password = body.get("password", "")

        if not email or not password:
            log_event("WARN", "Campos obligatorios faltantes para login")
            return build_response(400, {"error": "Los campos 'email' y 'password' son obligatorios"})

        # ── Autenticación con Cognito ────────────────────────────────────
        try:
            resp = cognito.initiate_auth(
                AuthFlow="USER_PASSWORD_AUTH",
                AuthParameters={
                    "USERNAME": email,
                    "PASSWORD": password,
                },
                ClientId=APP_CLIENT_ID,
            )
        except ClientError as e:
            code = e.response["Error"]["Code"]
            if code in ("NotAuthorizedException", "UserNotFoundException"):
                return build_response(401, {"error": "Email o contraseña incorrectos"})
            if code == "UserNotConfirmedException":
                return build_response(403, {"error": "La cuenta no ha sido confirmada. Revisa tu email."})
            log_event("ERROR", f"Error Cognito login: {str(e)}")
            return build_response(500, {"error": f"Error al iniciar sesión: {str(e)}"})

        auth_result = resp.get("AuthenticationResult", {})

        log_event("INFO", "Login exitoso", {"email": email})

        return build_response(
            200,
            {
                "access_token": auth_result.get("AccessToken"),
                "id_token": auth_result.get("IdToken"),
                "refresh_token": auth_result.get("RefreshToken"),
                "expires_in": auth_result.get("ExpiresIn", 3600),
                "token_type": auth_result.get("TokenType", "Bearer"),
            },
        )

    except Exception as e:
        log_event("ERROR", f"Error inesperado en login: {str(e)}")
        return build_response(500, {"error": f"Error inesperado: {str(e)}"})
