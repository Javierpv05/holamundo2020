#!/usr/bin/env python3
"""
seed_productos.py — Inserta los productos de Madam Tusan en DynamoDB.

Uso:
    python scripts/seed_productos.py [--stage dev|prod] [--tenant madam-tusan]

Requiere credenciales AWS configuradas (mismo perfil que el deploy de Serverless).
"""
import argparse
import uuid
import decimal
import boto3

# ── Catálogo de Madam Tusan ────────────────────────────────────────────────
PRODUCTOS = [
    {
        "nombre": "Arroz Chaufa de Pollo",
        "descripcion": "Arroz salteado al wok con pollo tierno, huevo, cebolla china y sillao. Clásico infaltable.",
        "precio": 22.00,
        "categoria": "Arroces",
        "disponible": True,
    },
    {
        "nombre": "Arroz Chaufa Marino",
        "descripcion": "Chaufa con langostinos, pulpo, calamares y mariscos frescos salteados al wok.",
        "precio": 32.00,
        "categoria": "Arroces",
        "disponible": True,
    },
    {
        "nombre": "Tallarín Saltado de Res",
        "descripcion": "Fideos de trigo salteados con tiras de res, verduras crujientes y salsa de ostión.",
        "precio": 26.00,
        "categoria": "Tallarines",
        "disponible": True,
    },
    {
        "nombre": "Tallarín Saltado de Pollo",
        "descripcion": "Fideos salteados al wok con pollo, pimiento, cebolla y salsa especial de la casa.",
        "precio": 22.00,
        "categoria": "Tallarines",
        "disponible": True,
    },
    {
        "nombre": "Wantán Frito (8 piezas)",
        "descripcion": "Dumplings crocantes rellenos de cerdo y camarón. Servidos con salsa agridulce.",
        "precio": 16.00,
        "categoria": "Entradas",
        "disponible": True,
    },
    {
        "nombre": "Sopa Wantán",
        "descripcion": "Caldo concentrado de pollo con wantanes rellenos, cebolla china y fideos de arroz.",
        "precio": 18.00,
        "categoria": "Sopas",
        "disponible": True,
    },
    {
        "nombre": "Sopa San Fan",
        "descripcion": "Sopa de fideos de vidrio con cerdo deshilachado, brotes de soja y caldo de res.",
        "precio": 19.00,
        "categoria": "Sopas",
        "disponible": True,
    },
    {
        "nombre": "Pato al Tamarindo",
        "descripcion": "Muslo de pato confitado con salsa de tamarindo, jengibre y cinco especias chinas.",
        "precio": 42.00,
        "categoria": "Especialidades",
        "disponible": True,
    },
    {
        "nombre": "Lomo Saltado Fusión",
        "descripcion": "Lomo de res con papas fritas, tomate, cebolla y un toque de sillao y pisco.",
        "precio": 35.00,
        "categoria": "Especialidades",
        "disponible": True,
    },
    {
        "nombre": "Pollo Chi Jau Kay",
        "descripcion": "Pollo crujiente bañado en salsa de frijol negro con ajonjolí y cebolla caramelizada.",
        "precio": 28.00,
        "categoria": "Especialidades",
        "disponible": True,
    },
    {
        "nombre": "Dim Sum Mixto (6 piezas)",
        "descripcion": "Selección de dim sum al vapor: har gow, siu mai y bao de cerdo. Servicio de té incluido.",
        "precio": 24.00,
        "categoria": "Entradas",
        "disponible": True,
    },
    {
        "nombre": "Helado de Té Verde Matcha",
        "descripcion": "Postre artesanal de matcha japonés con salsa de mango y crocante de sésamo.",
        "precio": 12.00,
        "categoria": "Postres",
        "disponible": True,
    },
]


def seed(stage: str, tenant_id: str) -> None:
    table_name = f"productos-{stage}"
    dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
    tabla = dynamodb.Table(table_name)

    print(f"\n🍜 Insertando {len(PRODUCTOS)} productos de Madam Tusan")
    print(f"   Tabla  : {table_name}")
    print(f"   Tenant : {tenant_id}\n")

    creados = 0
    errores = 0

    for p in PRODUCTOS:
        item = {
            "tenant_id": tenant_id,
            "producto_id": uuid.uuid4().hex,
            "nombre": p["nombre"],
            "descripcion": p["descripcion"],
            "precio": decimal.Decimal(str(p["precio"])),
            "categoria": p["categoria"],
            "disponible": p["disponible"],
        }
        try:
            tabla.put_item(Item=item)
            print(f"  ✅ {p['nombre']:<40} S/ {p['precio']:.2f}")
            creados += 1
        except Exception as e:
            print(f"  ❌ Error al insertar '{p['nombre']}': {e}")
            errores += 1

    print(f"\nResumen: {creados} insertados, {errores} errores.\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Seed de productos Madam Tusan en DynamoDB")
    parser.add_argument("--stage", default="dev", choices=["dev", "prod"], help="Stage de despliegue (default: dev)")
    parser.add_argument("--tenant", default="madam-tusan", help="Tenant ID (default: madam-tusan)")
    args = parser.parse_args()
    seed(args.stage, args.tenant)
