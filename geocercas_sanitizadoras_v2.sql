DROP TABLE IF EXISTS geocercas CASCADE;
DROP TABLE IF EXISTS items CASCADE;

CREATE TABLE geocercas (
    id SERIAL PRIMARY KEY,
    nombre TEXT,
    tipo integer, 
    geom geometry(Polygon, 4326)
);

CREATE TABLE items (
    id SERIAL PRIMARY KEY,
    nombre TEXT,
    tipo integer,
    geom geometry(Point, 4326)
);

-- tipo: 1 geocerca sanitizadora, 2 geocerca normal

INSERT INTO geocercas (nombre, geom,tipo) VALUES
('Puerto Sanitizadora', ST_GeomFromText('POLYGON ((-0.36976744186045007 39.45130813953488769, -0.35959302325579889 39.4707848837209383, -0.33575581395347331 39.47688953488372476, -0.3145348837209152 39.47834302325581746, -0.29709302325579889 39.47601744186047057, -0.27906976744184542 39.46497093023256042, -0.27267441860463615 39.45188953488372618, -0.27354651162789195 39.43561046511628376, -0.2834302325581245 39.41933139534884134, -0.30087209302324081 39.4068313953488385, -0.32267441860463614 39.40218023255814472, -0.3331395348837059 39.40305232558139892, -0.34941860465114777 39.41002906976744669, -0.37063953488370593 39.43125000000000568, -0.36976744186045007 39.45130813953488769))', 4326),1);

INSERT INTO geocercas (nombre, geom,tipo) VALUES
('Geocerca Prueba', ST_GeomFromText('POLYGON ((-0.32507152366652892 39.45463930119253604, -0.32689856386141325 39.4403274863326132, -0.33877432512816108 39.4391094595360201, -0.34212389881878225 39.44580860691726087, -0.34151488542048747 39.44854916720959181, -0.34151488542048747 39.44854916720959181, -0.32507152366652892 39.45463930119253604))', 4326),2);

-- items de prueba
INSERT INTO items (nombre, tipo, geom) VALUES
('Punto Dentro Puerto', 1, ST_GeomFromText('POINT(-0.27848 39.44885)', 4326)),  -- Dentro Puerto
('Punto Fuera Puerto', 2, ST_GeomFromText('POINT(-0.26021 39.44398)', 4326)), -- A ~1km fuera de Puerto
('Punto Dentro Geocerca Prueba',1, ST_GeomFromText('POINT(-0.33329 39.44581)', 4326)), -- Dentro de Geocerca Prueba
('Punto Lejano', 3, ST_GeomFromText('POINT(-0.91551 39.40927)', 4326)),-- Muy lejos
('Punto Fuera de Puerto a unos 500m', 1, ST_GeomFromText('POINT (-0.27149250771885514 39.43349185975693416)', 4326)), -- A unos 500 mts
('Punto Fuera de Puerto a unos 5 km', 1, ST_GeomFromText('POINT (-0.42419 39.47215)', 4326)); -- A unos 5 km

-- Crear índices espaciales
CREATE INDEX idx_geocercas_geom ON geocercas USING GIST (geom);
CREATE INDEX idx_items_geom ON items USING GIST (geom);


-- Funciones

---------------------------------------------
---- FUNCION 1 ------------------------------
---------------------------------------------
CREATE OR REPLACE FUNCTION intersects_item_geocerca_fuzzy(
    point_geom geometry,
    poly_geom  geometry,
    tolerance  double precision,
    option     integer
)
RETURNS boolean AS
$$
DECLARE
    computed_tolerance double precision;
    expanded_geom      geometry;
    diag               double precision;
    pct                double precision;
    srid               integer := ST_SRID(poly_geom);
BEGIN
    IF option NOT IN (1,2,3) THEN
        RAISE EXCEPTION 'Invalid option value: %, must be 1, 2 or 3', option;
    END IF;

    /* ----------------------------
       OPTION = 1  (comportamiento original)
       ---------------------------- */
    IF option = 1 THEN
        -- expand con unidades del CRS (misma semántica original)
        expanded_geom := ST_Expand(poly_geom, tolerance);

        IF point_geom && expanded_geom AND ST_Intersects(point_geom, poly_geom) THEN
            RAISE NOTICE 'Item % dentro del Geocerca %', ST_GeoHash(point_geom), ST_GeoHash(poly_geom);
            RETURN TRUE;
        END IF;

        IF ST_DWithin(point_geom, poly_geom, tolerance) THEN
            RAISE NOTICE 'Item % esta dentro de una tolerancia de % de la Geocerca %',
                ST_GeoHash(point_geom), tolerance, ST_GeoHash(poly_geom);
            RETURN TRUE;
        END IF;

        RAISE NOTICE 'Item % fuera del Geocerca %', ST_GeoHash(point_geom), ST_GeoHash(poly_geom);
        RETURN FALSE;
    END IF;

    /* ----------------------------
       OPTION = 2  (tolerance en METROS)
       ---------------------------- */
    IF option = 2 THEN
        -- Si la geometría está en WGS84 (4326) usamos geography para metros.
        IF srid = 4326 THEN
            -- expandemos la geocerca en metros usando ST_Buffer sobre geography
            expanded_geom := ST_Buffer(poly_geom::geography, tolerance)::geometry;

            IF ST_Intersects(point_geom, poly_geom) THEN
                RAISE NOTICE 'Item % dentro del Geocerca % (medido en metros)', ST_GeoHash(point_geom), ST_GeoHash(poly_geom);
                RETURN TRUE;
            END IF;

            IF ST_DWithin(point_geom::geography, poly_geom::geography, tolerance) THEN
                RAISE NOTICE 'Item % esta dentro de una tolerancia de % metros de la Geocerca %',
                    ST_GeoHash(point_geom), tolerance, ST_GeoHash(poly_geom);
                RETURN TRUE;
            END IF;

            RAISE NOTICE 'Item % fuera del Geocerca % (medido en metros)', ST_GeoHash(point_geom), ST_GeoHash(poly_geom);
            RETURN FALSE;
        ELSE
            -- Si no es 4326 asumimos que las unidades están en metros en el CRS proyectado
            expanded_geom := ST_Expand(poly_geom, tolerance);

            IF point_geom && expanded_geom AND ST_Intersects(point_geom, poly_geom) THEN
                RAISE NOTICE 'Item % dentro del Geocerca % (CRS proyectado)', ST_GeoHash(point_geom), ST_GeoHash(poly_geom);
                RETURN TRUE;
            END IF;

            IF ST_DWithin(point_geom, poly_geom, tolerance) THEN
                RAISE NOTICE 'Item % esta dentro de una tolerancia de % unidades CRS de la Geocerca %',
                    ST_GeoHash(point_geom), tolerance, ST_GeoHash(poly_geom);
                RETURN TRUE;
            END IF;

            RAISE NOTICE 'Item % fuera del Geocerca % (CRS proyectado)', ST_GeoHash(point_geom), ST_GeoHash(poly_geom);
            RETURN FALSE;
        END IF;
    END IF;

    /* ----------------------------
       OPTION = 3  (tolerance COMO PORCENTAJE de "tamaño" del poly_geom)
       Estrategia:
         - calcular la diagonal de la bbox;
         - si tolerance > 1 la interpretamos como porcentaje (ej. 10 => 10%);
           si tolerance <= 1 la tomamos como fracción (ej. 0.1 => 10%);
         - computed_tolerance = pct * diagonal;
         - para EPSG:4326 calculos de distancia en metros (geography).
       ---------------------------- */
    IF option = 3 THEN
        -- obtener diagonal de la caja envolvente (esquina 1 vs 3): manejamos 4326 con geography
        IF srid = 4326 THEN
            diag := ST_Distance(
                ST_PointN(ST_ExteriorRing(ST_Envelope(poly_geom)), 1)::geography,
                ST_PointN(ST_ExteriorRing(ST_Envelope(poly_geom)), 3)::geography
            );
        ELSE
            diag := ST_Distance(
                ST_PointN(ST_ExteriorRing(ST_Envelope(poly_geom)), 1),
                ST_PointN(ST_ExteriorRing(ST_Envelope(poly_geom)), 3)
            );
        END IF;

        -- seguridad: si diagonal es 0 (polígono muy pequeño) usamos una distancia mínima
        IF diag IS NULL OR diag <= 0 THEN
            diag := 0.0;
        END IF;

        -- interpretar tolerance: si >1 asumimos "porcentaje entero" (10 => 10%), si <=1 asumimos fracción (0.1 => 10%)
        IF tolerance > 1 THEN
            pct := tolerance / 100.0;
        ELSE
            pct := tolerance;
        END IF;

        computed_tolerance := pct * diag;

        -- si diag fue 0 y computed_tolerance queda 0, cae al comportamiento por defecto (usar tolerance tal cual)
        IF computed_tolerance <= 0 THEN
            computed_tolerance := tolerance;
        END IF;

        -- expandir en metros si es WGS84, sino con unidades CRS
        IF srid = 4326 THEN
            expanded_geom := ST_Buffer(poly_geom::geography, computed_tolerance)::geometry;
        ELSE
            expanded_geom := ST_Expand(poly_geom, computed_tolerance);
        END IF;

        -- ahora las comprobaciones (usar geography para ST_DWithin si es 4326)
        IF point_geom && expanded_geom AND ST_Intersects(point_geom, poly_geom) THEN
            RAISE NOTICE 'Item % dentro del Geocerca % (tolerancia relativa)', ST_GeoHash(point_geom), ST_GeoHash(poly_geom);
            RETURN TRUE;
        END IF;

        IF srid = 4326 THEN
            IF ST_DWithin(point_geom::geography, poly_geom::geography, computed_tolerance) THEN
                RAISE NOTICE 'Item % esta dentro de una tolerancia relativa de %%% (equivale a % metros) de la Geocerca %',
                    ST_GeoHash(point_geom), pct*100, computed_tolerance, ST_GeoHash(poly_geom);
                RETURN TRUE;
            END IF;
        ELSE
            IF ST_DWithin(point_geom, poly_geom, computed_tolerance) THEN
                RAISE NOTICE 'Item % esta dentro de una tolerancia relativa de %%% (equivale a % unidades CRS) de la Geocerca %',
                    ST_GeoHash(point_geom), pct*100, computed_tolerance, ST_GeoHash(poly_geom);
                RETURN TRUE;
            END IF;
        END IF;

        RAISE NOTICE 'Item % fuera del Geocerca % (tolerancia relativa)', ST_GeoHash(point_geom), ST_GeoHash(poly_geom);
        RETURN FALSE;
    END IF;

    -- no debería llegar aquí
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

----------------------------------------------------
--- FUNCION 2 --------------------------------------
----------------------------------------------------

-- Grado de pertenencia (0-1)
CREATE OR REPLACE FUNCTION membership_item_geocerca_fuzzy(
    point_geom geometry,
    poly_geom geometry,
    tolerance double precision,
    option integer
)
RETURNS double precision AS
$$
DECLARE
    dist double precision;
    grado double precision := 0.0;
    computed_tolerance double precision;
    diag double precision;
    pct double precision;
    srid integer := ST_SRID(poly_geom);
BEGIN
    IF option NOT IN (1,2,3) THEN
        RAISE EXCEPTION 'Invalid option value: %, must be 1, 2 or 3', option;
    END IF;

    /* ----------------------------
       OPTION 1: tolerancia CRS
       ---------------------------- */
    IF option = 1 THEN
        IF NOT (point_geom && ST_Expand(poly_geom, tolerance)) THEN
            RETURN 0.0;
        END IF;

        IF ST_Intersects(point_geom, poly_geom) THEN
            RETURN 1.0;
        END IF;

        dist := ST_Distance(point_geom, poly_geom);

        IF dist <= tolerance THEN
            grado := 1 - (dist / tolerance);
            RETURN grado;
        END IF;

        RETURN 0.0;
    END IF;

    /* ----------------------------
       OPTION 2: tolerancia en METROS
       ---------------------------- */
    IF option = 2 THEN
        IF srid = 4326 THEN
            IF ST_Intersects(point_geom, poly_geom) THEN
                RETURN 1.0;
            END IF;

            dist := ST_Distance(point_geom::geography, poly_geom::geography);

            IF dist <= tolerance THEN
                grado := 1 - (dist / tolerance);
                RETURN grado;
            END IF;

            RETURN 0.0;
        ELSE
            -- CRS proyectado (unidades en metros)
            RETURN membership_item_geocerca_fuzzy(point_geom, poly_geom, tolerance, 1);
        END IF;
    END IF;

    /* ----------------------------
       OPTION 3: tolerancia relativa (% del tamaño)
       ---------------------------- */
    IF option = 3 THEN
        -- diagonal de la bounding box
        IF srid = 4326 THEN
            diag := ST_Distance(
                ST_PointN(ST_ExteriorRing(ST_Envelope(poly_geom)), 1)::geography,
                ST_PointN(ST_ExteriorRing(ST_Envelope(poly_geom)), 3)::geography
            );
        ELSE
            diag := ST_Distance(
                ST_PointN(ST_ExteriorRing(ST_Envelope(poly_geom)), 1),
                ST_PointN(ST_ExteriorRing(ST_Envelope(poly_geom)), 3)
            );
        END IF;

        IF diag IS NULL OR diag <= 0 THEN
            diag := tolerance; -- fallback
        END IF;

        IF tolerance > 1 THEN
            pct := tolerance / 100.0; -- porcentaje
        ELSE
            pct := tolerance; -- fracción
        END IF;

        computed_tolerance := pct * diag;

        IF ST_Intersects(point_geom, poly_geom) THEN
            RETURN 1.0;
        END IF;

        IF srid = 4326 THEN
            dist := ST_Distance(point_geom::geography, poly_geom::geography);
        ELSE
            dist := ST_Distance(point_geom, poly_geom);
        END IF;

        IF dist <= computed_tolerance THEN
            grado := 1 - (dist / computed_tolerance);
            RETURN grado;
        END IF;

        RETURN 0.0;
    END IF;

    RETURN 0.0;
END;
$$ LANGUAGE plpgsql IMMUTABLE;



-----------------------------
-- EJEMPLOS PARA VERIFICACION BOOLEANA
-----------------------------

--1:original tolerancia en grados
--2:original tolerancia en metros
--3:original tolerancia porcentaje de 

-- OPCION 1 en Grados  
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
 
-- OPCION 2 en metros
 
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
 
 
 -- OPCION 3 en % de la geocerca
 
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
  
  
  
-----------------------------
-- EJEMPLOS PARA VERIFICACION DE GRADO DE PERTENENCIA
-----------------------------


-- OPCION 1 en Grados  
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
 
 
 -- OPCION 2 en metros
 
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
 

 -- OPCION 3 en % de la geocerca
 
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
  
 ---- VERIFICAR UNA COORDENADA LAT,LON 
 
 
 
 -- Verificio una coordenada, 
-- coordenada de ejemplo: lat = -0.29054, lon = 39.41271
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
	  
	  
	  
 
 
 
-- Verificio una coordenada, 
-- coordenada de ejemplo: lat = -0.29656, lon = 39.44925
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
	  
	  
	  
  
  