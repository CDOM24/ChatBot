# Chatbot Inteligente para el Centro de Competencias Digitales (CCD)

## Proyecto de Ciencia de Datos

Este repositorio documenta la implementación de un chatbot inteligente para el Centro de Competencias Digitales (CCD) de la Universidad Autónoma de Bucaramanga. El sistema permite responder consultas de estudiantes sobre la Ruta de Competencias Digitales, cursos realizados, oferta académica y noticias institucionales.

La solución fue implementada con n8n, PostgreSQL, Docker y Coolify, desplegada sobre una máquina virtual en Azure.

---

## Índice

- [1. Contexto del proyecto](#1-contexto-del-proyecto)
- [2. Objetivo general](#2-objetivo-general)
- [3. Objetivos específicos](#3-objetivos-específicos)
- [4. Alcance de la implementación](#4-alcance-de-la-implementación)
- [5. Arquitectura tecnológica](#5-arquitectura-tecnológica)
- [6. Servicios desplegados](#6-servicios-desplegados)
- [7. Archivos persistentes](#7-archivos-persistentes)
- [8. Base de datos PostgreSQL](#8-base-de-datos-postgresql)
- [9. Workflows de n8n](#9-workflows-de-n8n)
- [10. Flujo funcional del chatbot](#10-flujo-funcional-del-chatbot)
- [11. Funcionalidades implementadas](#11-funcionalidades-implementadas)
- [12. Relación con los requerimientos del proyecto](#12-relación-con-los-requerimientos-del-proyecto)
- [13. Estado actual](#13-estado-actual)
- [14. Comandos útiles](#14-comandos-útiles)
- [15. Conclusión](#15-conclusión)

---

## 1. Contexto del proyecto

La Universidad Autónoma de Bucaramanga plantea una transición desde el modelo tradicional de formación en informática hacia una Ruta de Competencias Digitales, organizada en tres pilares formativos:

- Competencias Digitales Básicas
- Analítica y Contenido Digital
- Tecnologías Transformativas

El propósito de esta ruta es fortalecer habilidades digitales en los estudiantes: analítica de datos, inteligencia artificial, comunicación digital, ciudadanía digital y uso estratégico de tecnologías emergentes.

Dado que la ruta involucra múltiples cursos, procesos de inscripción, pruebas diagnósticas, noticias, calendarios y distintas modalidades de oferta, se desarrolla un chatbot institucional que actúa como asistente digital del CCD.

---

## 2. Objetivo general

Diseñar e implementar un chatbot inteligente para el Centro de Competencias Digitales que permita a los estudiantes consultar información académica e institucional mediante flujos automatizados en n8n y una base de datos PostgreSQL.

---

## 3. Objetivos específicos

- Responder preguntas frecuentes sobre el CCD y la Ruta de Competencias Digitales.
- Consultar cursos realizados por estudiantes a partir de un código o identificador académico.
- Consultar la oferta de cursos disponible en la base de datos.
- Consultar noticias institucionales relacionadas con la UNAB.
- Integrar workflows de n8n con PostgreSQL para automatizar respuestas.
- Restaurar y adaptar una base de datos institucional para el funcionamiento del chatbot.

---

## 4. Alcance de la implementación

- Despliegue de n8n y PostgreSQL en Coolify sobre Azure VM.
- Restauración de la base de datos `ccd_db` desde archivo dump.
- Importación de workflows de n8n.
- Configuración de credenciales PostgreSQL en n8n.
- Consulta de cursos por estudiante desde Telegram.
- Consulta de noticias institucionales desde tabla dedicada.
- Montaje persistente de archivos dentro del contenedor n8n.

---

## 5. Arquitectura tecnológica

La solución se desplegó sobre una máquina virtual en Microsoft Azure, administrada mediante Coolify. Todos los servicios corren como contenedores Docker dentro del mismo stack.

### Componentes principales

| Componente | Rol |
|---|---|
| Azure VM | Servidor donde se ejecutan los contenedores |
| Docker | Plataforma de contenedores |
| Coolify | Administración del despliegue y proxy |
| n8n | Motor de automatización y orquestación del chatbot |
| PostgreSQL | Base de datos principal |
| Task runners | Ejecución externa de tareas de n8n |
| Traefik | Enrutamiento de servicios |

### Flujo general

```
Usuario / Telegram
        ↓
n8n Workflows
        ↓
PostgreSQL → ccd_db
        ↓
Respuesta al usuario
```

---

## 6. Servicios desplegados

| Servicio | Imagen | Puerto |
|---|---|---|
| n8n | `n8nio/n8n:2.10.2` | 5678 |
| task-runners | `n8nio/runners:2.10.2` | — |
| postgresql | `postgres:16-alpine` | 5432 |

---

## 7. Archivos persistentes

Se creó una carpeta persistente en la máquina virtual montada dentro del contenedor n8n:

```
/data/n8n-files  →  /files  (dentro del contenedor)
```

Archivos disponibles en `/files`:

```
ccd_bd.dump
Chat_bot-main/n8n/ccd-chatbot-flujo-principal-mvp.json
Chat_bot-main/n8n/ccd-chatbot-flujo-principal-completo.json
Chat_bot-main/n8n/ccd-scraper-noticias-oficiales.json
```

---

## 8. Base de datos PostgreSQL

Se restauró la base de datos institucional `ccd_db` desde un archivo dump, manteniéndola separada de la base interna de n8n para evitar conflictos.

### Tablas principales

| Tabla | Contenido |
|---|---|
| `estudiante` | Datos personales y académicos del estudiante |
| `cursos_estudiantes` | Materias matriculadas por cada estudiante |
| `oferta` | Cursos CCD disponibles con cupos, fechas y docente |
| `catalogo_materias_ccd` | Catálogo general de materias del CCD |
| `documentos_rag` | Documentos institucionales |
| `historial_conversacion` | Log de interacciones del chatbot |
| `sesiones` | Sesiones activas de usuarios |
| `solicitudes_validacion` | Solicitudes de validación académica |
| `registro_nota` | Notas académicas registradas |
| `noticias_unab` | Noticias institucionales recientes |

### Credencial PostgreSQL en n8n

| Parámetro | Valor |
|---|---|
| Host | `postgresql` (resuelto internamente en Docker) |
| Puerto | `5432` |
| Base de datos | `ccd_db` |
| SSL | Deshabilitado |
| SSH Tunnel | No |

---

## 9. Workflows de n8n

Se importaron tres workflows principales. Los archivos JSON fueron revisados y ajustados para incluir identificadores válidos antes de la importación.

| Workflow | Archivo | Estado |
|---|---|---|
| CCD - Chatbot flujo principal (MVP) | `ccd-chatbot-flujo-principal-mvp.json` | Importado |
| CCD - Chatbot flujo principal (completo) | `ccd-chatbot-flujo-principal-completo.json` | Importado |
| CCD - Scraper noticias oficiales | `ccd-scraper-noticias-oficiales.json` | Importado |

---

## 10. Flujo funcional del chatbot

El workflow principal sigue esta estructura de procesamiento de mensajes:

```
Telegram Trigger
        ↓
Code — Normalizar pregunta
        ↓
Code — Detectar FAQ e intención
        ↓
Switch — Intención
        ↓
Rutas especializadas
```

### Intenciones detectadas

| Intención | Descripción |
|---|---|
| `faq_directa` | Preguntas frecuentes con respuesta directa |
| `saludo` | Bienvenida al usuario |
| `calendario` | Fechas y eventos académicos |
| `oferta_cursos` | Cursos CCD disponibles |
| `cursos_estudiante` | Materias matriculadas por código de estudiante |
| `noticias` | Noticias recientes de la UNAB |
| `desconocido` | Fallback con registro en historial |

---

## 11. Funcionalidades implementadas

### 11.1 Respuestas frecuentes del CCD

El chatbot responde preguntas como:

- ¿Qué es el CCD?
- ¿Qué es la Ruta de Competencias Digitales?
- ¿Cuántos cursos debo tomar?
- ¿Qué es una insignia o certificado digital?

### 11.2 Consulta de cursos por estudiante

El usuario envía su código de estudiante. El sistema detecta el identificador, consulta PostgreSQL y devuelve los cursos registrados con semestre y fecha de matrícula.

```sql
SELECT
  e.nombre_completo,
  e.programa_academico,
  e.semestre_actual,
  ce.nombre_materia,
  ce.codigo_materia,
  ce.codigo_curso,
  ce.anio,
  ce.semestre,
  ce.fecha_matricula
FROM estudiante e
LEFT JOIN cursos_estudiantes ce
  ON e.id_estudiante = ce.id_estudiante
WHERE e.id_estudiante::TEXT = '{{ $json.id_estudiante }}'
ORDER BY ce.anio DESC, ce.semestre DESC, ce.nombre_materia ASC;
```

### 11.3 Consulta de noticias institucionales

Se creó la tabla `noticias_unab` con noticias reales de la UNAB. El chatbot devuelve las 5 más recientes ordenadas por fecha.

```sql
SELECT titulo, resumen, url, fecha_publicacion, categoria
FROM noticias_unab
ORDER BY fecha_publicacion DESC
LIMIT 5;
```

### 11.4 Consulta de oferta de cursos

La tabla `oferta` permite consultar cursos disponibles por pilar, modalidad, cupos y fechas de inicio y matrícula.

---

## 12. Relación con los requerimientos del proyecto

| Requerimiento | Estado |
|---|---|
| Chatbot para responder preguntas sobre el CCD | Implementado |
| Workflows n8n con rutas de consulta automatizadas | Implementado |
| Base de datos PostgreSQL con estudiantes y cursos | Implementado |
| Consulta de cursos realizados por estudiante | Implementado |
| Consulta de noticias y novedades del CCD | Implementado |
| Scraper de noticias oficiales | Estructura preparada |
| Documentos institucionales en base de datos | Estructura preparada |

---

## 13. Estado actual

| Componente | Estado |
|---|---|
| Azure VM | Operativa |
| Coolify | Funcionando |
| n8n | Desplegado |
| PostgreSQL | Desplegado |
| Base `ccd_db` | Restaurada |
| Archivos persistentes | Configurados |
| Workflows | Importados |
| Credencial PostgreSQL | Configurada |
| Consulta de cursos | Funcionando |
| Flujo de noticias | Funcionando |

---

## 14. Comandos útiles

**Ver contenedores activos:**

```bash
sudo docker ps --format "table {{.Names}}\t{{.Ports}}\t{{.Status}}"
```

**Entrar al contenedor n8n:**

```bash
sudo docker exec -it <id-contenedor-n8n> sh
```

**Entrar al contenedor PostgreSQL:**

```bash
sudo docker exec -it <id-contenedor-postgresql> sh
```

**Listar tablas de `ccd_db`:**

```bash
sudo docker exec -it <id-contenedor-postgresql> sh -c \
  'psql -U "$POSTGRES_USER" -d ccd_db -c "\dt"'
```

**Consultar noticias registradas:**

```bash
sudo docker exec -it <id-contenedor-postgresql> sh -c '
psql -U "$POSTGRES_USER" -d ccd_db -c "
SELECT id, titulo, fecha_publicacion, categoria
FROM noticias_unab
ORDER BY fecha_publicacion DESC;
"'
```

---

## 15. Conclusión

El proyecto implementa una solución funcional de chatbot inteligente para el CCD, integrando n8n, PostgreSQL, Docker, Coolify y una infraestructura cloud sobre Azure. El sistema responde consultas sobre el CCD, cursos realizados por estudiantes y noticias institucionales de forma automatizada, cubriendo los requerimientos planteados para el proyecto.
