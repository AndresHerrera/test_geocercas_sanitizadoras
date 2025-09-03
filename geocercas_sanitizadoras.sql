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

-- Booleano
CREATE OR REPLACE FUNCTION intersects_item_geocerca_fuzzy(
    point_geom geometry,
    poly_geom geometry,
    tolerance double precision
)
RETURNS boolean AS
$$
BEGIN
    IF point_geom && poly_geom AND ST_Intersects(point_geom, poly_geom) THEN
    	RAISE NOTICE 'Item % dentro del Geocerca %', ST_GeoHash(point_geom),ST_GeoHash(poly_geom);    
    	RETURN TRUE;
    END IF;

    IF ST_DWithin(point_geom, poly_geom, tolerance) then
    	RAISE NOTICE 'Item % esta dentro de una tolerancia de % de la Geocerca %', ST_GeoHash(point_geom),tolerance, ST_GeoHash(poly_geom);
        RETURN TRUE;
    END IF;
	RAISE NOTICE 'Item % fuera del Geocerca %', ST_GeoHash(point_geom),ST_GeoHash(poly_geom);
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- Grado de pertenencia (0-1)
CREATE OR REPLACE FUNCTION membership_item_geocerca_fuzzy(
    point_geom geometry,
    poly_geom geometry,
    tolerance double precision
)
RETURNS double precision AS
$$
DECLARE
    dist double precision;
    grado double precision;
BEGIN
    IF NOT (point_geom && ST_Expand(poly_geom, tolerance)) THEN
	    RAISE NOTICE 'Item % fuera del Geocerca %', ST_GeoHash(point_geom),ST_GeoHash(poly_geom);    
    	RETURN 0.0;
    END IF;

    IF ST_Intersects(point_geom, poly_geom) THEN
	    RAISE NOTICE 'Item % dentro del Geocerca %', ST_GeoHash(point_geom),ST_GeoHash(poly_geom);      
    	RETURN 1.0;
    END IF;

    dist := ST_Distance(point_geom, poly_geom);

    IF dist <= tolerance then
    	grado :=1 - (dist / tolerance);
    	RAISE NOTICE 'Item % esta dentro de una tolerancia de % de la Geocerca %', ST_GeoHash(point_geom),grado, ST_GeoHash(poly_geom);
        RETURN grado;
    END IF;
	RAISE NOTICE 'Item % fuera del Geocerca %', ST_GeoHash(point_geom),ST_GeoHash(poly_geom);
    RETURN 0.0;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- Consultas de Prueba

-- Evaluar si hay intersección difusa (umbral 1 km aprox 0.01 grados)
SELECT p.nombre AS item, p.tipo as item_tipo, g.nombre AS geocerca, g.tipo as geocerca_tipo,
       intersects_item_geocerca_fuzzy(p.geom, g.geom, 0.01) AS interseccion
FROM items as p
JOIN geocercas as g
  ON p.geom && ST_Expand(g.geom, 0.01);
 
 
 -- Obtener grado difuso de pertenencia (umbral 1 km aprox 0.01 grados)
SELECT p.nombre AS item, p.tipo as item_tipo, g.nombre AS geocerca, g.tipo as geocerca_tipo,
       membership_item_geocerca_fuzzy(p.geom, g.geom, 0.01) AS grado
FROM items as p
JOIN geocercas as g
  ON p.geom && ST_Expand(g.geom, 0.01);