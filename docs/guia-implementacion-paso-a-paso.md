# Guía de implementación — Paso a paso (CCD UNAB)

Documento complementario al [diseño del flujo n8n](./diseno-flujo-n8n-chatbot-ccd-unab.md).

---

## 1. Orden recomendado

| Orden | Tarea | Archivo / recurso |
|-------|--------|-------------------|
| 1 | Crear base PostgreSQL + pgvector en Coolify | `database/001_schema_ccd.sql` |
| 2 | Cargar datos de prueba | `database/002_seed_ccd.sql` |
| 3 | Crear bot en [@BotFather](https://t.me/BotFather) y guardar token | Variable `TELEGRAM_BOT_TOKEN` |
| 4 | Importar workflow MVP en n8n | `n8n/ccd-chatbot-flujo-principal-mvp.json` |
| 5 | Configurar credencial Telegram y activar workflow | n8n UI |
| 6 | Probar FAQ, saludo, calendario, oferta, noticias y cursos estudiante | Telegram |
| 7 | Importar plantilla completa y conectar PostgreSQL | `n8n/ccd-chatbot-flujo-principal-completo.json` |
| 8 | Desplegar API RAG y conectar rama `rag_documentos` | Variable `CCD_RAG_API_URL` |
| 9 | Importar scraper y programar cron | `n8n/ccd-scraper-noticias-oficiales.json` |
| 10 | Agregar Web Chat (webhook) | Rama en workflow completo |

---

## 2. PostgreSQL en Coolify

1. Crear servicio **PostgreSQL** (imagen con extensión vector o instalar `pgvector` manualmente).
2. Crear base dedicada, por ejemplo: `ccd_chatbot`.
3. Ejecutar en orden:

```bash
psql -h HOST -U USER -d ccd_chatbot -f database/001_schema_ccd.sql
psql -h HOST -U USER -d ccd_chatbot -f database/002_seed_ccd.sql
```

4. En n8n → **Credentials** → PostgreSQL:
   - Host, puerto, base `ccd_chatbot`, usuario y contraseña.
   - Nombre sugerido: `PostgreSQL CCD`.

**Nota:** Si el modelo de embeddings no usa 1536 dimensiones, editar `vector(1536)` en `document_chunks` antes de ejecutar el schema.

---

## 3. Importar workflow MVP en n8n

1. Abrir n8n → **Workflows** → menú **Import from File**.
2. Seleccionar: `n8n/ccd-chatbot-flujo-principal-mvp.json`.
3. Abrir el nodo **Telegram Trigger** y crear/asignar credencial **Telegram API** con el token del bot.
4. Repetir credencial en los tres nodos **Telegram - Respuesta**.
5. **Activar** el workflow.
6. Escribir al bot desde Telegram.

### Pruebas MVP

| Mensaje de prueba | Intención esperada |
|-------------------|-------------------|
| `Hola` | saludo |
| `¿Qué es el CCD?` | faq_directa |
| `¿Cuántos cursos debo tomar?` | faq_directa |
| `¿Cuál es el clima hoy?` | desconocido |

---

## 4. MVP extendido (ya en flujo principal)

El archivo `ccd-chatbot-flujo-principal-mvp.json` ya incluye ramas PostgreSQL para calendario, oferta, noticias y cursos estudiante.

1. Asignar credencial **PostgreSQL CCD** en los 4 nodos Postgres activos.
2. Asignar credencial **Telegram** también en **Telegram - Respuesta dinamica**.
3. Probar:
   - `¿Cuándo es la prueba diagnóstica?` → calendario
   - `¿Qué cursos hay de analítica?` → oferta_cursos
   - `Mis cursos realizados` → pedir código
   - `mis cursos 202012345` → historial demo

## 5. Siguiente fase (RAG y extras)

1. Activar nodo **PostgreSQL - Log desconocido** (opcional).
2. Importar `n8n/ccd-chatbot-flujo-principal-completo.json` o agregar rama RAG al MVP.
3. Desplegar API RAG y workflow scraper de noticias.

---

## 6. API RAG (contrato mínimo)

La rama **HTTP - API RAG** espera:

**Request**

```http
POST /api/rag/query
Content-Type: application/json

{
  "pregunta": "¿Qué requisitos tiene la insignia?",
  "top_k": 5
}
```

**Response**

```json
{
  "contexto": "Texto concatenado de fragmentos relevantes...",
  "fragmentos": [
    { "documento_id": 1, "score": 0.89, "contenido": "..." }
  ]
}
```

El nodo LLM solo debe ejecutarse si `contexto` no está vacío.

---

## 7. Variables de entorno sugeridas (Coolify / n8n)

| Variable | Uso |
|----------|-----|
| `TELEGRAM_BOT_TOKEN` | Bot Telegram |
| `CCD_DATABASE_URL` | Conexión PostgreSQL CCD |
| `CCD_RAG_API_URL` | URL base API RAG |
| `CCD_NOTICIAS_URL` | URL página a scrapear |
| `OPENAI_API_KEY` o Azure equivalente | Solo rama RAG |

---

## 8. Checklist antes de producción

- [ ] Workflow MVP probado en Telegram (FAQ, saludo, calendario, oferta, noticias, cursos)
- [ ] Schema y seed ejecutados sin errores
- [ ] Credenciales n8n separadas (n8n DB ≠ CCD DB)
- [ ] PostgreSQL CCD en nodos Calendario, Oferta, Cursos estudiante, Noticias
- [ ] Rama RAG responde solo con contexto documental (pendiente)
- [ ] Scraper corre por cron, no en cada mensaje (pendiente)
- [ ] Preguntas `desconocido` registradas en `preguntas_sin_resolver` (log desactivado)
- [ ] Web chat con respuesta HTTP al webhook (pendiente)

---

## 9. Siguiente entregable opcional

- Servicio **API RAG** (FastAPI + pgvector) con endpoint `/api/rag/query`
- Página **Web Chat** que haga POST al webhook `ccd-web-chat`
- Script de **ingesta de documentos** PDF institucionales a `document_chunks`
