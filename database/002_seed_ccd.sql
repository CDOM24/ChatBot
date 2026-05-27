-- Datos de prueba para desarrollo local / MVP
-- Ejecutar en ccd_db después de 001_schema_ccd.sql. Idempotente (re-ejecutable).
-- Requiere pgcrypto (creado en 001) para digest() en noticias_ccd.

INSERT INTO cursos_ccd (codigo, nombre, categoria, modalidad, descripcion) VALUES
('CCD-101', 'Competencias Digitales Básicas', 'Competencias Digitales Básicas', 'virtual', 'Curso obligatorio de la ruta CCD.'),
('CCD-201', 'Analítica de Datos para la Toma de Decisiones', 'Analítica y Contenido Digital', 'virtual', 'Curso complementario pilar analítica.'),
('CCD-202', 'Producción de Contenido Digital', 'Analítica y Contenido Digital', 'virtual', 'Curso complementario pilar contenido.'),
('CCD-301', 'Inteligencia Artificial Generativa', 'Tecnologías Transformativas', 'virtual', 'Curso complementario tecnologías transformativas.')
ON CONFLICT (codigo) DO NOTHING;

INSERT INTO calendario_ccd (evento, slug, fecha_inicio, fecha_fin, descripcion) VALUES
('Inscripción ruta CCD', 'inscripcion-ruta-ccd', '2026-02-01', '2026-02-28', 'Periodo de inscripción a la ruta de competencias digitales.'),
('Prueba diagnóstica', 'prueba-diagnostica', '2026-03-10', NULL, 'Evaluación diagnóstica inicial de competencias digitales.'),
('Inicio de cursos', 'inicio-cursos', '2026-03-17', NULL, 'Inicio de cursos del periodo académico CCD.')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO estudiantes_sinteticos (codigo, nombre, programa) VALUES
('202012345', 'Estudiante Demo UNAB', 'Ingeniería de Sistemas')
ON CONFLICT (codigo) DO NOTHING;

INSERT INTO matriculas (estudiante_id, curso_id, estado, fecha_matricula)
SELECT e.id, c.id, 'aprobado', '2025-08-15'
FROM estudiantes_sinteticos e
CROSS JOIN cursos_ccd c
WHERE e.codigo = '202012345'
  AND c.codigo = 'CCD-101'
ON CONFLICT (estudiante_id, curso_id) DO NOTHING;

INSERT INTO noticias_ccd (titulo, fecha_publicacion, enlace, resumen, hash_contenido) VALUES
(
    'Convocatoria ruta de competencias digitales 2026',
    '2026-01-15',
    'https://www.unab.edu.co/ejemplo-noticia-ccd', -- TODO: reemplazar por URL oficial real
    'Se abre convocatoria para estudiantes de pregrado interesados en la ruta CCD.',
    encode(digest('convocatoria-ruta-ccd-2026', 'sha256'), 'hex')
)
ON CONFLICT (hash_contenido) DO NOTHING;

INSERT INTO documentos (titulo, fuente, tipo)
SELECT 'Guía institucional CCD — Insignia y certificación', 'CCD UNAB', 'institucional'
WHERE NOT EXISTS (
    SELECT 1 FROM documentos
    WHERE titulo = 'Guía institucional CCD — Insignia y certificación'
);
