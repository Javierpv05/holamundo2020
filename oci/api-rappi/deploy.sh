#!/bin/bash
# Script de despliegue automatizado e idempotente para API Rappi en OCI

set -e

echo "Iniciando despliegue de API Rappi en OCI..."

# 1. Obtener OCID del Tenancy (Compartimiento Root) desde la configuración de OCI
COMPARTMENT_ID=$(grep -m 1 tenancy ~/.oci/config | tr -d ' ' | cut -d "=" -f 2)
if [ -z "$COMPARTMENT_ID" ]; then
    echo "No se pudo obtener el COMPARTMENT_ID. Asegúrate de tener ~/.oci/config configurado."
    exit 1
fi
echo "Compartimiento Root: $COMPARTMENT_ID"

# 2. Buscar una Subnet disponible (necesaria para Fn App y API Gateway)
SUBNET_ID=$(oci network subnet list -c "$COMPARTMENT_ID" --lifecycle-state AVAILABLE --query 'data[0].id' --raw-output 2>/dev/null || echo "")
if [ -z "$SUBNET_ID" ] || [ "$SUBNET_ID" == "None" ]; then
    echo "ERROR: No se encontró una Subnet en el compartimiento. Por favor crea una VCN/Subnet primero."
    exit 1
fi
echo "Subnet detectada: $SUBNET_ID"

APP_NAME="rappi-app"
FN_NAME="guardar-estado"
GW_NAME="api-rappi"
DEPLOYMENT_NAME="rappi-deployment"
PATH_PREFIX="/rappi"

# 3. Crear Fn App (Idempotente)
echo "Verificando Fn App '$APP_NAME'..."
APP_ID=$(oci fn app list -c "$COMPARTMENT_ID" --name "$APP_NAME" --query 'data[0].id' --raw-output 2>/dev/null || echo "")
if [ -z "$APP_ID" ] || [ "$APP_ID" == "None" ]; then
    echo "Creando Fn App '$APP_NAME'..."
    APP_ID=$(oci fn app create -c "$COMPARTMENT_ID" --name "$APP_NAME" --subnet-ids "[\"$SUBNET_ID\"]" --query 'data.id' --raw-output)
fi
echo "App ID: $APP_ID"

# 4. Desplegar Función con Fn CLI
echo "Desplegando la función '$FN_NAME'..."
cd function
fn deploy --app "$APP_NAME"
cd ..

FUNC_OCID=$(oci fn function list --app-id "$APP_ID" --name "$FN_NAME" --query 'data[0].id' --raw-output)
echo "Función OCID: $FUNC_OCID"

# 5. Crear API Gateway (Idempotente)
echo "Verificando API Gateway '$GW_NAME'..."
GW_ID=$(oci api-gateway gateway list -c "$COMPARTMENT_ID" --display-name "$GW_NAME" --lifecycle-state ACTIVE --query 'data.items[0].id' --raw-output 2>/dev/null || echo "")
if [ -z "$GW_ID" ] || [ "$GW_ID" == "None" ]; then
    echo "Creando API Gateway '$GW_NAME'..."
    GW_ID=$(oci api-gateway gateway create -c "$COMPARTMENT_ID" --endpoint-type PUBLIC --subnet-id "$SUBNET_ID" --display-name "$GW_NAME" --query 'data.id' --raw-output)
    echo "Esperando a que el API Gateway esté ACTIVE..."
    oci api-gateway gateway get --gateway-id "$GW_ID" --wait-for-state ACTIVE > /dev/null
fi
echo "Gateway ID: $GW_ID"

# 6. Crear/Actualizar API Deployment
echo "Generando spec JSON para el deployment..."
TOKEN="eyJraWQiOiJqWHZVRUI4OExKRTB1TjByZEIvVGpISXNDSEN5dGg5SnBLQXV5MDlLbCtjPSIsImFsZyI6IlJTMjU2In0.eyJzdWIiOiJkNGE4ODQzOC03MDcxLTcwN2ItMTgzZC1jNDU1ODYxY2YxNzgiLCJlbWFpbF92ZXJpZmllZCI6ZmFsc2UsImlzcyI6Imh0dHBzOi8vY29nbml0by1pZHAudXMtZWFzdC0xLmFtYXpvbmF3cy5jb20vdXMtZWFzdC0xXzVtMU5sNUlaOCIsImNvZ25pdG86dXNlcm5hbWUiOiJkNGE4ODQzOC03MDcxLTcwN2ItMTgzZC1jNDU1ODYxY2YxNzgiLCJjdXN0b206dGVuYW50X2lkIjoibWFkYW0tdHVzYW4iLCJvcmlnaW5fanRpIjoiNDhkZWFjNWUtZTdlZS00MzI3LTk0MjEtYmIzYWU0YTRjYzkwIiwiYXVkIjoiM25sMGg2dDJlMmJwNDN1OGZhNjNpZ3ZtaXYiLCJldmVudF9pZCI6ImVmYmU2NDZhLTI4ODEtNDRhOS1iYmU0LWIxNjhiOWZlNTIxNSIsInRva2VuX3VzZSI6ImlkIiwiYXV0aF90aW1lIjoxNzgyNTA4NjU5LCJuYW1lIjoidHJhYmFqYWRvcjEiLCJleHAiOjE3ODI1MTIyNTksImlhdCI6MTc4MjUwODY1OSwianRpIjoiMGExMWYxZTgtMjA0MS00MDdlLWFlZmQtOTE1MGY1ZWNiYjdkIiwiZW1haWwiOiJqcHYyMjk3QGdtYWlsLmNvbSJ9.qn1sGKZ5PlScRONhRzZII7tosseG5o7isebtKFEUBy72w8Ioz7FpmwzbEDJ6CXaol2PXFDCsHrPlhG9YVRuzt4S8UslAzDT5WCkFvnjgeeHURc-ysiH4Zi5SBrHeUFetKponWYTyMvMa-IYrBwfcL1cRfdBzspeasIM9Abuml6-Jw-ttY3JPDn_AHioYgagvG3OxTY_5sLIucCOBe4D0DmI8KJ2XzfRykRPQ_4Qr2c-s9zptomizUbPgdihzwWCKj1y0ycNgIGuHWCMk598sLtQMvIwqm7XfH3_vJDpY6G6QqJ2Ybcm8cIrN0U5u0TpcrNT_45Mjm8Xjh1gY8xjJ-w"
cat <<EOF > deployment-spec.json
{
  "routes": [
    {
      "path": "/pedidos",
      "methods": ["POST"],
      "backend": {
        "type": "HTTP_BACKEND",
        "url": "https://xoogztranc.execute-api.us-east-1.amazonaws.com/dev/pedidos"
      },
      "requestPolicies": {
        "headerTransformations": {
          "setHeaders": {
            "items": [
              {
                "name": "Authorization",
                "values": ["Bearer $TOKEN"],
                "ifExists": "OVERWRITE"
              }
            ]
          }
        }
      }
    },
    {
      "path": "/estado",
      "methods": ["POST"],
      "backend": {
        "type": "ORACLE_FUNCTIONS_BACKEND",
        "functionId": "$FUNC_OCID"
      }
    }
  ]
}
EOF

DEPLOYMENT_ID=$(oci api-gateway deployment list -c "$COMPARTMENT_ID" --gateway-id "$GW_ID" --display-name "$DEPLOYMENT_NAME" --lifecycle-state ACTIVE --query 'data.items[0].id' --raw-output 2>/dev/null || echo "")

if [ -z "$DEPLOYMENT_ID" ] || [ "$DEPLOYMENT_ID" == "None" ]; then
    echo "Creando API Deployment..."
    DEPLOYMENT_ID=$(oci api-gateway deployment create -c "$COMPARTMENT_ID" --gateway-id "$GW_ID" --display-name "$DEPLOYMENT_NAME" --path-prefix "$PATH_PREFIX" --specification file://deployment-spec.json --query 'data.id' --raw-output)
    echo "Esperando a que el Deployment esté ACTIVE..."
    oci api-gateway deployment get --deployment-id "$DEPLOYMENT_ID" --wait-for-state ACTIVE > /dev/null
else
    echo "Actualizando API Deployment existente..."
    oci api-gateway deployment update --deployment-id "$DEPLOYMENT_ID" --specification file://deployment-spec.json > /dev/null
    echo "Esperando a que la actualización termine..."
    oci api-gateway deployment get --deployment-id "$DEPLOYMENT_ID" --wait-for-state ACTIVE > /dev/null
fi

# Limpieza temporal del spec JSON
rm deployment-spec.json

# 7. Imprimir Resultados
GW_HOSTNAME=$(oci api-gateway gateway get --gateway-id "$GW_ID" --query 'data.hostname' --raw-output)
echo ""
echo "#########################################################"
echo "Despliegue finalizado exitosamente."
echo "URL Base de tu API Gateway: https://$GW_HOSTNAME$PATH_PREFIX"
echo ""
echo "Prueba las rutas con cURL:"
echo "1. Redirección hacia AWS:"
echo "   curl -X POST https://$GW_HOSTNAME$PATH_PREFIX/pedidos -H 'Content-Type: application/json' -d '{\"pedido\": 123}'"
echo ""
echo "2. Invocación de Oracle Function (Guardar Estado):"
echo "   curl -X POST https://$GW_HOSTNAME$PATH_PREFIX/estado -H 'Content-Type: application/json' -d '{\"pedido_id\": \"999\", \"estado\": \"ENTREGADO\"}'"
echo "#########################################################"
