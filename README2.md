# Documentación: Sistema de Geocercas Sanitizadoras v2

## Descripción General

Este archivo SQL (`geocercas_sanitizadoras_v2.sql`) implementa un sistema de geocercas (geofencing) con lógica difusa (fuzzy logic) para la gestión de zonas sanitizadoras. El sistema permite determinar si un punto geográfico está dentro o cerca de una geocerca utilizando diferentes métodos de tolerancia.

## Estructura de la Base de Datos

### Tablas

#### 1. Tabla `geocercas`
```sql
CREATE TABLE geocercas (
    id SERIAL PRIMARY KEY,
    nombre TEXT,
    tipo integer, 
    geom geometry(Polygon, 4326)
);
```

**Campos:**
- `id`: Identificador único autoincremental
- `nombre`: Nombre descriptivo de la geocerca
- `tipo`: Tipo de geocerca (1 = sanitizadora, 2 = normal)
- `geom`: Geometría poligonal en sistema de coordenadas WGS84 (EPSG:4326)

#### 2. Tabla `items`
```sql
CREATE TABLE items (
    id SERIAL PRIMARY KEY,
    nombre TEXT,
    tipo integer,
    geom geometry(Point, 4326)
);
```

**Campos:**
- `id`: Identificador único autoincremental
- `nombre`: Nombre descriptivo del punto
- `tipo`: Tipo de item
- `geom`: Geometría puntual en sistema de coordenadas WGS84 (EPSG:4326)

### Índices Espaciales

El sistema incluye índices GIST para optimizar las consultas espaciales:
- `idx_geocercas_geom`: Índice espacial para la tabla geocercas
- `idx_items_geom`: Índice espacial para la tabla items

## Funciones Principales

### 1. `intersects_item_geocerca_fuzzy()`

**Propósito:** Determina si un punto intersecta con una geocerca utilizando lógica difusa.

**Parámetros:**
- `point_geom`: Geometría del punto a evaluar
- `poly_geom`: Geometría del polígono de la geocerca
- `tolerance`: Valor de tolerancia
- `option`: Opción de cálculo (1, 2, o 3)

**Opciones de Tolerancia:**

#### Opción 1: Tolerancia en Unidades CRS
- Utiliza `ST_Expand()` con las unidades del sistema de coordenadas
- Comportamiento original del sistema
- Apropiado para sistemas de coordenadas proyectadas

#### Opción 2: Tolerancia en Metros
- Convierte geometrías a `geography` para cálculos en metros
- Ideal para coordenadas WGS84 (EPSG:4326)
- Proporciona mediciones precisas en metros

#### Opción 3: Tolerancia Relativa (Porcentaje)
- Calcula la tolerancia como porcentaje del tamaño de la geocerca
- Utiliza la diagonal de la caja envolvente como referencia
- Adaptable a geocercas de diferentes tamaños

**Valores de Retorno:**
- `TRUE`: El punto está dentro o cerca de la geocerca
- `FALSE`: El punto está fuera de la geocerca

### 2. `membership_item_geocerca_fuzzy()`

**Propósito:** Calcula el grado de pertenencia (0-1) de un punto a una geocerca.

**Parámetros:**
- `point_geom`: Geometría del punto a evaluar
- `poly_geom`: Geometría del polígono de la geocerca
- `tolerance`: Valor de tolerancia
- `option`: Opción de cálculo (1, 2, o 3)

**Valores de Retorno:**
- `1.0`: Punto completamente dentro de la geocerca
- `0.0`: Punto completamente fuera de la geocerca
- `0.0 < valor < 1.0`: Grado de pertenencia proporcional a la distancia

## Datos de Prueba

### Geocercas de Ejemplo

1. **Puerto Sanitizadora** (tipo 1)
   - Geocerca de prueba para zona sanitizadora
   - Ubicada en coordenadas de Valencia, España

2. **Geocerca Prueba** (tipo 2)
   - Geocerca normal de prueba
   - Polígono más pequeño para pruebas

### Items de Prueba

1. **Punto Dentro Puerto** (tipo 1)
   - Ubicado dentro de la geocerca Puerto Sanitizadora

2. **Punto Fuera Puerto** (tipo 2)
   - Ubicado aproximadamente a 1km fuera del Puerto

3. **Punto Dentro Geocerca Prueba** (tipo 1)
   - Ubicado dentro de la Geocerca Prueba

4. **Punto Lejano** (tipo 3)
   - Ubicado muy lejos de ambas geocercas

5. **Punto Fuera de Puerto a unos 500m** (tipo 1)
   - Ubicado a aproximadamente 500 metros del Puerto

6. **Punto Fuera de Puerto a unos 5 km** (tipo 1)
   - Ubicado a aproximadamente 5 kilómetros del Puerto

## Ejemplos de Uso

### Verificación Booleana

#### Opción 1: Tolerancia en Grados
```sql
SELECT 
    p.nombre AS item, 
    p.id as item_id,
    p.tipo   AS item_tipo, 
    g.nombre AS geocerca,
    g.id as geocerca_id,
    g.tipo   AS geocerca_tipo,
    intersects_item_geocerca_fuzzy(p.geom, g.geom, 0.01, 1) AS interseccion
FROM items AS p
JOIN geocercas AS g
  ON intersects_item_geocerca_fuzzy(p.geom, g.geom, 0.01, 1);
```

#### Opción 2: Tolerancia en Metros
```sql
SELECT 
    p.nombre AS item, 
    p.id as item_id,
    p.tipo   AS item_tipo, 
    g.nombre AS geocerca,
    g.id as geocerca_id,
    g.tipo   AS geocerca_tipo,
    intersects_item_geocerca_fuzzy(p.geom, g.geom, 500, 2) AS interseccion
FROM items AS p
JOIN geocercas AS g
  ON intersects_item_geocerca_fuzzy(p.geom, g.geom, 500, 2);
```

#### Opción 3: Tolerancia Relativa
```sql
SELECT 
    p.nombre AS item, 
    p.id as item_id,
    p.tipo   AS item_tipo, 
    g.nombre AS geocerca,
    g.id as geocerca_id,
    g.tipo   AS geocerca_tipo,
    intersects_item_geocerca_fuzzy(p.geom, g.geom, 0.01, 3) AS interseccion
FROM items AS p
JOIN geocercas AS g
  ON intersects_item_geocerca_fuzzy(p.geom, g.geom, 0.01, 3);
```

### Verificación de Grado de Pertenencia

#### Opción 1: Tolerancia en Grados
```sql
SELECT 
    p.nombre AS item, 
    p.id as item_id,
    p.tipo   AS item_tipo, 
    g.nombre AS geocerca,
    g.id as geocerca_id,
    g.tipo   AS geocerca_tipo,
    membership_item_geocerca_fuzzy(p.geom, g.geom, 0.01, 1) AS grado
FROM items AS p
JOIN geocercas AS g
  ON intersects_item_geocerca_fuzzy(p.geom, g.geom, 0.01, 1);
```

#### Opción 2: Tolerancia en Metros
```sql
SELECT 
    p.nombre AS item, 
    p.id as item_id,
    p.tipo   AS item_tipo, 
    g.nombre AS geocerca,
    g.id as geocerca_id,
    g.tipo   AS geocerca_tipo,
    membership_item_geocerca_fuzzy(p.geom, g.geom, 100, 2) AS grado
FROM items AS p
JOIN geocercas AS g
  ON intersects_item_geocerca_fuzzy(p.geom, g.geom, 100, 2);
```

#### Opción 3: Tolerancia Relativa
```sql
SELECT 
    p.nombre AS item, 
    p.id as item_id,
    p.tipo   AS item_tipo, 
    g.nombre AS geocerca,
    g.id as geocerca_id,
    g.tipo   AS geocerca_tipo,
    membership_item_geocerca_fuzzy(p.geom, g.geom, 0.5, 3) AS grado
FROM items AS p
JOIN geocercas AS g
  ON intersects_item_geocerca_fuzzy(p.geom, g.geom, 0.5, 3);
```

### Verificación de Coordenadas Manuales

#### Verificación con Tolerancia en Metros
```sql
SELECT 
    'punto_manual' AS item,
    NULL AS item_id,
    'coordenada' AS item_tipo,
    g.nombre AS geocerca,
    g.id AS geocerca_id,
    g.tipo AS geocerca_tipo,
    intersects_item_geocerca_fuzzy(
        ST_SetSRID(ST_MakePoint(-0.29054,39.41271), 4326), -- (lon, lat)
        g.geom,
        500,
        2
    ) AS interseccion
FROM geocercas AS g
WHERE intersects_item_geocerca_fuzzy(
        ST_SetSRID(ST_MakePoint(-0.29054,39.41271), 4326), -- (lon, lat)
        g.geom,
        500,
        2
      );
```

#### Verificación de Grado de Pertenencia
```sql
SELECT 
    'punto_manual' AS item,
    NULL AS item_id,
    'coordenada' AS item_tipo,
    g.nombre AS geocerca,
    g.id AS geocerca_id,
    g.tipo AS geocerca_tipo,
    membership_item_geocerca_fuzzy(
        ST_SetSRID(ST_MakePoint(-0.29656,39.44925), 4326), -- (lon, lat)
        g.geom,
        0.5,
        3
    ) AS grado
FROM geocercas AS g
WHERE intersects_item_geocerca_fuzzy(
        ST_SetSRID(ST_MakePoint(-0.29656,39.44925), 4326), -- (lon, lat)
        g.geom,
        0.5,
        3
      );
```

## Requisitos del Sistema

- **PostgreSQL** con extensión PostGIS
- **PostGIS** habilitado para operaciones geométricas
- **Sistema de coordenadas:** WGS84 (EPSG:4326)

## Características Técnicas

### Optimizaciones
- Índices espaciales GIST para consultas rápidas
- Funciones marcadas como `IMMUTABLE` para optimización de consultas
- Uso de `geography` para cálculos precisos en metros

### Manejo de Errores
- Validación de parámetros de entrada
- Manejo de geometrías nulas o inválidas
- Valores de fallback para casos extremos

### Logging
- Mensajes informativos con `RAISE NOTICE`
- Identificación de geometrías mediante `ST_GeoHash`
- Información detallada sobre cálculos de tolerancia

## Notas de Implementación

- Las coordenadas se manejan en formato (longitud, latitud)
- La tolerancia en la opción 3 se interpreta como porcentaje si es > 1, o como fracción si es ≤ 1
- El sistema es compatible con diferentes sistemas de coordenadas proyectadas
- Las funciones están optimizadas para consultas frecuentes en sistemas de monitoreo en tiempo real
