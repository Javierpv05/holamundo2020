#!/bin/bash

# ==============================================================================
# Script de Prueba de API - Sistema de Pedidos Taco Bell
# ==============================================================================

# IMPORTANTE: Reemplaza estas URLs con las de tus API Gateways
API_CATALOGO="https://u3vs997az9.execute-api.us-east-1.amazonaws.com/dev"
API_PEDIDOS="https://g4bx3071ec.execute-api.us-east-1.amazonaws.com/dev"
API_WORKFLOW="https://ej0bjjyyie.execute-api.us-east-1.amazonaws.com/dev"

TENANT="madam-tusan"

echo "======================================================"
echo "1. Creando un Producto en ms-catalogo..."
echo "======================================================"
PROD_RES=$(curl -s -X POST "$API_CATALOGO/productos" \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id": "'$TENANT'",
    "nombre": "Taco Supreme",
    "precio": 15.99,
    "descripcion": "Delicioso taco con doble carne",
    "disponible": true
  }')
echo $PROD_RES | jq . || echo $PROD_RES
PROD_ID=$(echo $PROD_RES | grep -o '"producto_id": "[^"]*' | cut -d'"' -f4)
echo "Producto creado ID: $PROD_ID"
echo ""

echo "======================================================"
echo "2. Listando Productos..."
echo "======================================================"
curl -s -X GET "$API_CATALOGO/productos?tenant_id=$TENANT" | jq . || curl -s -X GET "$API_CATALOGO/productos?tenant_id=$TENANT"
echo ""
echo ""

echo "======================================================"
echo "3. Creando un Pedido en ms-pedidos..."
echo "======================================================"
PED_RES=$(curl -s -X POST "$API_PEDIDOS/pedidos" \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id": "'$TENANT'",
    "cliente_nombre": "Juan Perez",
    "items": [
      {
        "producto_id": "'$PROD_ID'",
        "cantidad": 2,
        "precio": 15.99
      }
    ],
    "total": 31.98
  }')
echo $PED_RES | jq . || echo $PED_RES
PEDIDO_ID=$(echo $PED_RES | grep -o '"pedido_id": "[^"]*' | cut -d'"' -f4)
echo "Pedido creado ID: $PEDIDO_ID"
echo ""

echo "======================================================"
echo "4. Consultando Estado del Pedido..."
echo "======================================================"
curl -s -X GET "$API_PEDIDOS/pedidos/$PEDIDO_ID?tenant_id=$TENANT" | jq . || curl -s -X GET "$API_PEDIDOS/pedidos/$PEDIDO_ID?tenant_id=$TENANT"
echo ""
echo ""

echo "======================================================"
echo "5. Avanzando Paso a COCINA (ms-workflow)..."
echo "======================================================"
curl -s -X POST "$API_WORKFLOW/pasos/avanzar" \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id": "'$TENANT'",
    "pedido_id": "'$PEDIDO_ID'",
    "paso": "COCINA",
    "usuario": "operador-pruebas"
  }' | jq . || \
curl -s -X POST "$API_WORKFLOW/pasos/avanzar" \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id": "'$TENANT'",
    "pedido_id": "'$PEDIDO_ID'",
    "paso": "COCINA",
    "usuario": "operador-pruebas"
  }'
echo ""
echo ""

echo "======================================================"
echo "6. Avanzando Paso a DESPACHO (ms-workflow)..."
echo "======================================================"
curl -s -X POST "$API_WORKFLOW/pasos/avanzar" \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id": "'$TENANT'",
    "pedido_id": "'$PEDIDO_ID'",
    "paso": "DESPACHO",
    "usuario": "operador-pruebas"
  }' | jq . || \
curl -s -X POST "$API_WORKFLOW/pasos/avanzar" \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id": "'$TENANT'",
    "pedido_id": "'$PEDIDO_ID'",
    "paso": "DESPACHO",
    "usuario": "operador-pruebas"
  }'
echo ""
echo ""

echo "======================================================"
echo "7. Consultando Estado Final del Pedido..."
echo "======================================================"
# Dale 1-2 seg a DynamoDB y Step Functions para sincronizar
sleep 2
curl -s -X GET "$API_PEDIDOS/pedidos/$PEDIDO_ID?tenant_id=$TENANT" | jq . || curl -s -X GET "$API_PEDIDOS/pedidos/$PEDIDO_ID?tenant_id=$TENANT"
echo ""

echo "Pruebas finalizadas."
