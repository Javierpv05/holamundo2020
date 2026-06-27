#!/bin/bash
# Script de despliegue automatizado e idempotente para API Rappi en OCI

set -e

echo "=========================================================="
echo "Iniciando despliegue de API Rappi en OCI..."
echo "=========================================================="

# DATOS FIJOS (NO CAMBIAR)
COMPARTMENT_ID="ocid1.tenancy.oc1..aaaaaaaad6gx6xntyy5hdei7piyhurlkq2zh3dxluixrcgoeltluek5yjuga"
REGION="us-chicago-1"
SUBNET_ID="ocid1.subnet.oc1.us-chicago-1.aaaaaaaat2lnw7oa4v45emqnxbdmcjtgr52jklq6ebg5df6qyqkfjgx3yafa"
APP_NAME="rappi-app"
FN_NAME="guardar-estado"
GW_NAME="api-rappi"
DEPLOYMENT_NAME="rappi-deployment"
PATH_PREFIX="/rappi"
TOKEN="eyJraWQiOiJqWHZVRUI4OExKRTB1TjByZEIvVGpISXNDSEN5dGg5SnBLQXV5MDlLbCtjPSIsImFsZyI6IlJTMjU2In0.eyJzdWIiOiJkNGE4ODQzOC03MDcxLTcwN2ItMTgzZC1jNDU1ODYxY2YxNzgiLCJlbWFpbF92ZXJpZmllZCI6ZmFsc2UsImlzcyI6Imh0dHBzOi8vY29nbml0by1pZHAudXMtZWFzdC0xLmFtYXpvbmF3cy5jb20vdXMtZWFzdC0xXzVtMU5sNUlaOCIsImNvZ25pdG86dXNlcm5hbWUiOiJkNGE4ODQzOC03MDcxLTcwN2ItMTgzZC1jNDU1ODYxY2YxNzgiLCJjdXN0b206dGVuYW50X2lkIjoibWFkYW0tdHVzYW4iLCJvcmlnaW5fanRpIjoiNDhkZWFjNWUtZTdlZS00MzI3LTk0MjEtYmIzYWU0YTRjYzkwIiwiYXVkIjoiM25sMGg2dDJlMmJwNDN1OGZhNjNpZ3ZtaXYiLCJldmVudF9pZCI6ImVmYmU2NDZhLTI4ODEtNDRhOS1iYmU0LWIxNjhiOWZlNTIxNSIsInRva2VuX3VzZSI6ImlkIiwiYXV0aF90aW1lIjoxNzgyNTA4NjU5LCJuYW1lIjoidHJhYmFqYWRvcjEiLCJleHAiOjE3ODI1MTIyNTksImlhdCI6MTc4MjUwODY1OSwianRpIjoiMGExMWYxZTgtMjA0MS00MDdlLWFlZmQtOTE1MGY1ZWNiYjdkIiwiZW1haWwiOiJqcHYyMjk3QGdtYWlsLmNvbSJ9.qn1sGKZ5PlScRONhRzZII7tosseG5o7isebtKFEUBy72w8Ioz7FpmwzbEDJ6CXaol2PXFDCsHrPlhG9YVRuzt4S8UslAzDT5WCkFvnjgeeHURc-ysiH4Zi5SBrHeUFetKponWYTyMvMa-IYrBwfcL1cRfdBzspeasIM9Abuml6-Jw-ttY3JPDn_AHioYgagvG3OxTY_5sLIucCOBe4D0DmI8KJ2XzfRykRPQ_4Qr2c-s9zptomizUbPgdihzwWCKj1y0ycNgIGuHWCMk598sLtQMvIwqm7XfH3_vJDpY6G6QqJ2Ybcm8cIrN0U5u0TpcrNT_45Mjm8Xjh1gY8xjJ-w"
AWS_URL="https://xoogztranc.execute-api.us-east-1.amazonaws.com/dev/pedidos"

echo "Configuración:"
echo "- Compartment: $COMPARTMENT_ID"
echo "- Subnet: $SUBNET_ID"
echo "- Región: $REGION"

# 1. Configurar contexto de Fn CLI (Idempotente)
echo ""
echo "[1/5] Configurando contexto de Fn CLI..."
fn create context oci-context --provider oracle 2>/dev/null || true
fn use context oci-context
fn update context oracle.compartment-id "$COMPARTMENT_ID"
fn update context api-url "https://functions.$REGION.oraclecloud.com"
fn update context registry "$REGION.ocir.io/$(oci os ns get --query 'data' --raw-output)/rappi-repo"

# 2. Crear Fn App (Idempotente usando OCI CLI)
echo ""
echo "[2/5] Verificando/Creando Fn App '$APP_NAME'..."
APP_ID=$(oci fn app list -c "$COMPARTMENT_ID" --display-name "$APP_NAME" --query 'data[0].id' --raw-output 2>/dev/null || echo "")

if [ -z "$APP_ID" ] || [ "$APP_ID" == "None" ] || [ "$APP_ID" == "null" ]; then
    echo "  -> Creando Fn App '$APP_NAME'..."
    fn create app "$APP_NAME" --annotation oracle.com/oci/subnetIds="[\"$SUBNET_ID\"]"
    sleep 2
    APP_ID=$(oci fn app list -c "$COMPARTMENT_ID" --display-name "$APP_NAME" --query 'data[0].id' --raw-output)
else
    echo "  -> Fn App '$APP_NAME' ya existe (ID: $APP_ID)."
fi

# 3. Desplegar Función con Fn CLI
echo ""
echo "[3/5] Desplegando la función '$FN_NAME'..."
cd "$(dirname "$0")/function"
fn deploy --app "$APP_NAME"
cd ..

FUNC_OCID=$(oci fn function list --app-id "$APP_ID" --display-name "$FN_NAME" --query 'data[0].id' --raw-output)
echo "  -> Función OCID: $FUNC_OCID"

# 4. Crear API Gateway
echo ""
echo "[4/5] Verificando/Creando API Gateway '$GW_NAME'..."
GW_ID=$(oci api-gateway gateway list -c "$COMPARTMENT_ID" --display-name "$GW_NAME" --lifecycle-state ACTIVE --query 'data.items[0].id' --raw-output 2>/dev/null || echo "")
if [ -z "$GW_ID" ] || [ "$GW_ID" == "None" ]; then
    echo "  -> Creando API Gateway '$GW_NAME'..."
    GW_ID=$(oci api-gateway gateway create -c "$COMPARTMENT_ID" --endpoint-type PUBLIC --subnet-id "$SUBNET_ID" --display-name "$GW_NAME" --query 'data.id' --raw-output)
    echo "  -> Esperando a que el Gateway esté ACTIVE..."
    oci api-gateway gateway get --gateway-id "$GW_ID" --wait-for-state ACTIVE > /dev/null
else
    echo "  -> Gateway '$GW_NAME' ya existe ($GW_ID)."
fi

# 5. Crear Deployment
echo ""
echo "[5/5] Configurando rutas en API Deployment..."
cat > deployment-spec.json <<EOF
{
  "routes": [
    {
      "path": "/pedidos",
      "methods": ["POST"],
      "backend": {
        "type": "HTTP_BACKEND",
        "url": "$AWS_URL"
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
    echo "  -> Creando Deployment..."
    DEPLOYMENT_ID=$(oci api-gateway deployment create -c "$COMPARTMENT_ID" --gateway-id "$GW_ID" --display-name "$DEPLOYMENT_NAME" --path-prefix "$PATH_PREFIX" --specification file://deployment-spec.json --query 'data.id' --raw-output)
    echo "  -> Esperando a que el Deployment esté ACTIVE..."
    oci api-gateway deployment get --deployment-id "$DEPLOYMENT_ID" --wait-for-state ACTIVE > /dev/null
else
    echo "  -> Deployment ya existe, actualizando..."
    oci api-gateway deployment update --deployment-id "$DEPLOYMENT_ID" --specification file://deployment-spec.json > /dev/null
    oci api-gateway deployment get --deployment-id "$DEPLOYMENT_ID" --wait-for-state ACTIVE > /dev/null
fi

rm deployment-spec.json

# 6. Mostrar URL final
GW_HOSTNAME=$(oci api-gateway gateway get --gateway-id "$GW_ID" --query 'data.hostname' --raw-output)

echo ""
echo "=========================================================="
echo "✅ DESPLIEGUE COMPLETADO"
echo "=========================================================="
echo "URL Base del API Gateway:"
echo "👉 https://$GW_HOSTNAME$PATH_PREFIX"
echo ""
echo "Rutas disponibles:"
echo "✅ POST https://$GW_HOSTNAME$PATH_PREFIX/pedidos"
echo "✅ POST https://$GW_HOSTNAME$PATH_PREFIX/estado"
echo "=========================================================="
