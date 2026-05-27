-- CCD UNAB — Esquema PostgreSQL + pgvector
-- Ejecutar conectado a la base existente ccd_db (NO crea otra base de datos).
-- Ejemplo: psql -U postgres -d ccd_db -f 001_schema_ccd.sql
-- NO ejecutar en la base interna de n8n.

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------------
-- Documentos RAG
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS documentos (
    id              BIGSERIAL PRIMARY KEY,
    titulo          TEXT NOT NULL,
    fuente          TEXT,
    url             TEXT,
    tipo            TEXT DEFAULT 'institucional',
    activo          BOOLEAN DEFAULT TRUE,
    creado_en       TIMESTAMPTZ DEFAULT NOW(),
    actualizado_en  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS document_chunks (
    id              BIGSERIAL PRIMARY KEY,
    documento_id    BIGINT NOT NULL REFERENCES documentos(id) ON DELETE CASCADE,
    chunk_index     INT NOT NULL,
    contenido       TEXT NOT NULL,
    -- vector(1536): embeddings tipo OpenAI (text-embedding-3-small, ada-002, etc.).
    -- Si luego se usa un modelo local (p. ej. MiniLM), migrar columna a vector(384).
    embedding       vector(1536),
    metadata        JSONB DEFAULT '{}'::jsonb,
    creado_en       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_document_chunks_documento
    ON document_chunks(documento_id);

-- IVFFlat falla en tablas vacías o sin filas con embedding. Crear en fase RAG tras ingesta:
-- CREATE INDEX idx_document_chunks_embedding ON document_chunks
--     USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- ---------------------------------------------------------------------------
-- Cursos y calendario
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS cursos_ccd (
    id              BIGSERIAL PRIMARY KEY,
    codigo          TEXT UNIQUE,
    nombre          TEXT NOT NULL,
    categoria       TEXT NOT NULL CHECK (categoria IN (
        'Competencias Digitales Básicas',
        'Analítica y Contenido Digital',
        'Tecnologías Transformativas'
    )),
    modalidad       TEXT,
    descripcion     TEXT,
    activo          BOOLEAN DEFAULT TRUE,
    creado_en       TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS calendario_ccd (
    id              BIGSERIAL PRIMARY KEY,
    evento          TEXT NOT NULL,
    slug            TEXT UNIQUE,
    fecha_inicio    DATE,
    fecha_fin       DATE,
    descripcion     TEXT,
    activo          BOOLEAN DEFAULT TRUE,
    creado_en       TIMESTAMPTZ DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- Noticias (alimentadas por workflow scraper)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS noticias_ccd (
    id                  BIGSERIAL PRIMARY KEY,
    titulo              TEXT NOT NULL,
    fecha_publicacion   DATE,
    enlace              TEXT NOT NULL,
    resumen             TEXT,
    hash_contenido      TEXT UNIQUE,
    activo              BOOLEAN DEFAULT TRUE,
    disponible_chatbot  BOOLEAN DEFAULT TRUE,
    creado_en           TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_noticias_fecha
    ON noticias_ccd(fecha_publicacion DESC);

-- ---------------------------------------------------------------------------
-- Estudiantes sintéticos y matrículas
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS estudiantes_sinteticos (
    id              BIGSERIAL PRIMARY KEY,
    codigo          TEXT UNIQUE NOT NULL,
    nombre          TEXT NOT NULL,
    programa        TEXT,
    activo          BOOLEAN DEFAULT TRUE,
    creado_en       TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS matriculas (
    id              BIGSERIAL PRIMARY KEY,
    estudiante_id   BIGINT NOT NULL REFERENCES estudiantes_sinteticos(id) ON DELETE CASCADE,
    curso_id        BIGINT NOT NULL REFERENCES cursos_ccd(id) ON DELETE CASCADE,
    estado          TEXT NOT NULL DEFAULT 'en_progreso' CHECK (estado IN (
        'en_progreso', 'aprobado', 'pendiente'
    )),
    fecha_matricula DATE,
    UNIQUE (estudiante_id, curso_id)
);

-- ---------------------------------------------------------------------------
-- Mejora continua del chatbot
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS preguntas_sin_resolver (
    id                  BIGSERIAL PRIMARY KEY,
    pregunta_original   TEXT NOT NULL,
    pregunta_normalizada TEXT,
    intencion_detectada TEXT,
    canal               TEXT,
    session_id          TEXT,
    creado_en           TIMESTAMPTZ DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- Vistas útiles para n8n
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_oferta_cursos AS
SELECT
    categoria,
    nombre,
    modalidad,
    descripcion
FROM cursos_ccd
WHERE activo = TRUE
ORDER BY categoria, nombre;

CREATE OR REPLACE VIEW v_noticias_chatbot AS
SELECT
    titulo,
    fecha_publicacion,
    enlace,
    resumen
FROM noticias_ccd
WHERE activo = TRUE
  AND disponible_chatbot = TRUE
ORDER BY fecha_publicacion DESC NULLS LAST;
