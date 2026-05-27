# Diseño del flujo principal n8n — Chatbot Inteligente CCD UNAB

**Proyecto:** Chatbot Inteligente para el Centro de Competencias Digitales (CCD) de la Universidad Autónoma de Bucaramanga (UNAB)  
**Versión del documento:** 1.0  
**Orquestador:** n8n | **Canal principal:** Telegram | **Canal secundario:** Web chat  
**Infraestructura:** Azure VM + Coolify | **Datos y RAG:** PostgreSQL + pgvector

---

## 1. Introducción

Este documento define el **diseño del flujo principal en n8n** del chatbot institucional del CCD UNAB, antes de su implementación en producción.

El chatbot atiende a estudiantes que consultan información sobre cursos, calendario, ruta de competencias digitales, noticias y avance académico en el marco del Centro de Competencias Digitales. n8n actúa como **orquestador central**: recibe mensajes desde Telegram o la web, normaliza el texto, aplica reglas y filtros sin IA, consulta PostgreSQL cuando corresponde y solo invoca el modelo de lenguaje o la API RAG cuando la pregunta lo exige.

El diseño prioriza **eficiencia operativa y costo controlado**: la mayoría de interacciones se resuelven con FAQ predefinidas, clasificación por palabras clave y consultas SQL, reservando IA para casos que requieren contexto documental o interpretación compleja.

---

## 2. Objetivo del flujo

El flujo principal debe cumplir las siguientes funciones, en este orden lógico:

| Paso | Acción | Uso de IA |
|------|--------|-----------|
| 1 | Recibir preguntas desde **Telegram** o **web chat** | No |
| 2 | **Normalizar** el texto (minúsculas, sin tildes, espacios) | No |
| 3 | **Detectar preguntas frecuentes** y respuestas directas | No |
| 4 | **Clasificar intención** con reglas y palabras clave | No (salvo rama opcional LLM) |
| 5 | **Consultar base de datos** solo cuando la intención lo requiera | No |
| 6 | Invocar **RAG + modelo** únicamente para preguntas complejas o documentales | Sí |
| 7 | **Responder** al estudiante de forma clara y breve | Según rama |

**Principio rector:** cada mensaje recorre el camino más corto hacia una respuesta válida; el modelo no participa en saludos, FAQ ni consultas estructuradas a tablas.

---

## 3. Arquitectura general del flujo

```
Usuario (Telegram / Web Chat)
        ↓
   Entrada n8n
   ├── Telegram Trigger
   └── Webhook Web Chat
        ↓
   Code — Normalizar pregunta
        ↓
   Code — Detectar FAQ e intención rápida (sin IA)
        ↓
   ¿respuesta_directa?
   ├── Sí → Responder canal (Telegram / Web)
   └── No → Switch — Intención
                ├── faq_directa      → respuesta_directa
                ├── saludo           → respuesta_directa
                ├── calendario       → PostgreSQL / Google Sheets
                ├── cursos_estudiante → PostgreSQL (+ código estudiante)
                ├── oferta_cursos    → PostgreSQL (tabla cursos)
                ├── noticias         → PostgreSQL (noticias precargadas)
                ├── rag_documentos   → API RAG → LLM con contexto
                └── desconocido      → mensaje estándar (opcional: clasificador LLM)
        ↓
   Respuesta al usuario (Telegram / Web)
```

### 3.1 Componentes del ecosistema

| Componente | Rol |
|------------|-----|
| Coolify | Despliegue y administración de servicios en Azure VM |
| n8n | Orquestación del flujo conversacional |
| PostgreSQL + pgvector | Datos académicos, noticias, calendario, chunks y embeddings RAG |
| API RAG | Búsqueda semántica en documentos institucionales |
| Telegram Bot | Canal principal de interacción |
| Web chat | Canal secundario (webhook) |
| Workflow scraper (separado) | Actualización programada de noticias |

---

## 4. Principio de ahorro de consumo del modelo

### 4.1 Cuándo SÍ usar el modelo de IA

El modelo (y/o la cadena RAG → modelo) se activa **solo** cuando se cumple al menos una de estas condiciones:

- La pregunta **no** coincide con preguntas frecuentes ni reglas del nodo de detección rápida.
- La pregunta **no** puede clasificarse de forma confiable con reglas (rama `desconocido` → clasificador LLM opcional).
- La pregunta requiere **explicación institucional** basada en documentos oficiales (insignia, requisitos, duración, certificación, etc.).
- La pregunta requiere **búsqueda RAG** en fragmentos vectorizados de documentos CCD/UNAB.

### 4.2 Cuándo NO usar el modelo de IA

| Tipo de interacción | Mecanismo |
|---------------------|-----------|
| Saludos | `respuesta_directa` en Code |
| Preguntas frecuentes (qué es CCD, ruta, cuántos cursos) | `respuesta_directa` |
| Calendario (fechas, inscripción, prueba diagnóstica) | Consulta SQL / hoja |
| Listado u oferta de cursos por categoría | Consulta SQL |
| Cursos realizados del estudiante | Consulta SQL con código |
| Noticias y convocatorias | Registros ya almacenados (scraper aparte) |
| Mensajes fuera de alcance | Plantilla fija o prompt corto sin RAG |
| Mensajes sin información suficiente | Respuesta estándar en rama `desconocido` |

**Impacto esperado:** menor latencia, menor costo por token y mayor previsibilidad en respuestas institucionales.

---

## 5. Nodos principales del workflow en n8n

Nombre sugerido del workflow: **`CCD - Chatbot flujo principal`**

### 5.1 Telegram Trigger

- **Tipo:** Telegram Trigger  
- **Función:** Recibe `message.text` de estudiantes que escriben al bot.  
- **Salida típica:** `$json.message.text`, `chat.id`, datos del usuario.  
- **Nota:** Unificar en nodos posteriores el campo `pregunta` para que el mismo flujo sirva a Telegram y web.

### 5.2 Webhook — Web Chat

- **Tipo:** Webhook (POST)  
- **Función:** Recibe JSON desde la página web tipo chat, por ejemplo: `{ "pregunta": "...", "session_id": "...", "codigo_estudiante": "..." }`.  
- **Función:** Canal secundario; debe converger con Telegram **antes** del nodo de normalización (Merge o Set común).

### 5.3 Code — Normalizar pregunta

- **Tipo:** Code (JavaScript)  
- **Función:** Unificar formato para comparación de reglas y FAQ.

```javascript
const preguntaOriginal = $json.message?.text || $json.pregunta || "";

const normalizada = preguntaOriginal
  .toLowerCase()
  .normalize("NFD")
  .replace(/[\u0300-\u036f]/g, "")
  .trim();

return [
  {
    json: {
      pregunta_original: preguntaOriginal,
      pregunta_normalizada: normalizada
    }
  }
];
```

| Campo salida | Descripción |
|--------------|-------------|
| `pregunta_original` | Texto tal como lo envió el usuario |
| `pregunta_normalizada` | Texto para reglas (minúsculas, sin tildes) |

### 5.4 Code — Detectar FAQ e intención rápida

- **Tipo:** Code (JavaScript)  
- **Función:** Clasificación por palabras clave y respuestas FAQ **sin IA**.

```javascript
const p = $json.pregunta_normalizada;

let intencion = "desconocido";
let respuesta_directa = null;

if (
  p.includes("que es el ccd") ||
  p.includes("centro de competencias digitales")
) {
  intencion = "faq_directa";
  respuesta_directa = "El Centro de Competencias Digitales, CCD, es una iniciativa institucional orientada al fortalecimiento de habilidades digitales en la comunidad universitaria, mediante cursos sobre cultura digital, analítica, contenido digital y tecnologías transformativas.";
}

else if (
  p.includes("ruta de competencias digitales") ||
  p.includes("competencias digitales")
) {
  intencion = "faq_directa";
  respuesta_directa = "La Ruta de Competencias Digitales está organizada en tres pilares: Competencias Digitales Básicas, Analítica y Contenido Digital, y Tecnologías Transformativas.";
}

else if (
  p.includes("cuantos cursos") ||
  p.includes("cuantos debo tomar") ||
  p.includes("que cursos debo tomar")
) {
  intencion = "faq_directa";
  respuesta_directa = "La ruta contempla un curso obligatorio de competencias digitales básicas y cursos complementarios en Analítica y Contenido Digital y Tecnologías Transformativas.";
}

else if (
  p.includes("insignia") ||
  p.includes("certificacion") ||
  p.includes("certificado")
) {
  intencion = "rag_documentos";
}

else if (
  p.includes("cuando") ||
  p.includes("fecha") ||
  p.includes("inscripcion") ||
  p.includes("prueba diagnostica") ||
  p.includes("inicio de cursos")
) {
  intencion = "calendario";
}

else if (
  p.includes("he tomado") ||
  p.includes("mis cursos") ||
  p.includes("historial") ||
  p.includes("cursos realizados")
) {
  intencion = "cursos_estudiante";
}

else if (
  p.includes("noticias") ||
  p.includes("convocatorias") ||
  p.includes("nuevos cursos") ||
  p.includes("novedades")
) {
  intencion = "noticias";
}

else if (
  p.includes("analitica") ||
  p.includes("contenido digital") ||
  p.includes("tecnologias transformativas") ||
  p.includes("ia generativa")
) {
  intencion = "oferta_cursos";
}

else if (
  p.includes("hola") ||
  p.includes("buenas") ||
  p.includes("buenos dias") ||
  p.includes("buenas tardes")
) {
  intencion = "saludo";
  respuesta_directa = "Hola, soy el asistente del Centro de Competencias Digitales. Puedes preguntarme sobre cursos, calendario, ruta de competencias digitales, noticias o tu historial académico.";
}

return [
  {
    json: {
      ...$json,
      intencion,
      respuesta_directa
    }
  }
];
```

**Orden de evaluación:** las condiciones más específicas deben ir antes que las genéricas (por ejemplo, `competencias digitales` en FAQ antes que en oferta si se refinan reglas en versiones futuras).

### 5.5 Switch — Intención

- **Tipo:** Switch  
- **Campo:** `{{ $json.intencion }}`  
- **Modo:** Reglas por valor exacto  

| Ruta (output) | Valor `intencion` |
|---------------|-------------------|
| 0 | `faq_directa` |
| 1 | `saludo` |
| 2 | `calendario` |
| 3 | `cursos_estudiante` |
| 4 | `oferta_cursos` |
| 5 | `noticias` |
| 6 | `rag_documentos` |
| 7 | `desconocido` (fallback) |

**Optimización opcional:** si `respuesta_directa` no es null, un nodo **IF** previo al Switch puede enviar directamente a “Responder” sin evaluar más ramas.

---

## 6. Ramas del flujo

### 6.1 Rama FAQ directa

| Aspecto | Detalle |
|---------|---------|
| Activación | `intencion === "faq_directa"` y `respuesta_directa` definida |
| Respuesta | `{{ $json.respuesta_directa }}` |
| Modelo | No |
| Base de datos | No |
| RAG | No |

Nodo sugerido: **Telegram Send Message** o respuesta HTTP al web chat con el texto fijo.

---

### 6.2 Rama saludo

| Aspecto | Detalle |
|---------|---------|
| Activación | `intencion === "saludo"` |
| Respuesta | `{{ $json.respuesta_directa }}` |
| Modelo | No |

Mismo patrón que FAQ directa; mensaje de bienvenida y orientación de capacidades del bot.

---

### 6.3 Rama calendario

| Aspecto | Detalle |
|---------|---------|
| Activación | `intencion === "calendario"` |
| Fuente | PostgreSQL (`calendario_ccd`) o Google Sheets sincronizado |
| Modelo | No |

**Flujo sugerido:**

1. Extraer término clave de `pregunta_normalizada` (inscripción, prueba diagnóstica, inicio de cursos).  
2. Nodo **PostgreSQL** — `SELECT evento, fecha, descripcion FROM calendario_ccd WHERE ...`.  
3. Formatear respuesta en **Code** o plantilla Set.

**Ejemplo:**

- *Pregunta:* ¿Cuándo es la prueba diagnóstica?  
- *Respuesta:* La prueba diagnóstica está registrada para el **[fecha]** según el calendario oficial del CCD. (fecha proveniente de la consulta, no inventada.)

---

### 6.4 Rama cursos realizados (`cursos_estudiante`)

| Aspecto | Detalle |
|---------|---------|
| Activación | `intencion === "cursos_estudiante"` |
| Requisito | Código de estudiante |
| Fuente | PostgreSQL — tabla `estudiantes_sinteticos` / `matriculas` (o base del profesor cuando esté disponible) |

**Flujo:**

```
Switch → cursos_estudiante
    ↓
IF — ¿existe codigo_estudiante en contexto/sesión?
    ├── No  → "Para consultar tus cursos realizados necesito tu código de estudiante."
    └── Sí  → PostgreSQL SELECT cursos aprobados/en progreso
              → Formatear lista breve
```

No usar IA para listar historial; solo formateo de filas SQL.

---

### 6.5 Rama oferta de cursos (`oferta_cursos`)

| Aspecto | Detalle |
|---------|---------|
| Activación | `intencion === "oferta_cursos"` |
| Fuente | Tabla `cursos_ccd` en PostgreSQL |
| Modelo | No |

**Consulta orientativa:**

```sql
SELECT nombre, categoria, modalidad, estado
FROM cursos_ccd
WHERE activo = true
ORDER BY categoria, nombre;
```

**Respuesta estructurada por categoría:**

1. Competencias Digitales Básicas  
2. Analítica y Contenido Digital  
3. Tecnologías Transformativas  

El nodo Code agrupa resultados por `categoria` y genera un mensaje corto por pilar.

---

### 6.6 Rama noticias

| Aspecto | Detalle |
|---------|---------|
| Activación | `intencion === "noticias"` |
| Fuente | PostgreSQL — tabla `noticias_ccd` |
| Scraping en tiempo real | **Prohibido** en este flujo |

**Flujo:**

1. `SELECT titulo, fecha, enlace, resumen FROM noticias_ccd WHERE activo = true ORDER BY fecha DESC LIMIT 5`.  
2. Devolver lista numerada al usuario.

El scraping corre en el workflow **`CCD - Scraper noticias oficiales`** (sección 10).

---

### 6.7 Rama RAG documentos (`rag_documentos`)

| Aspecto | Detalle |
|---------|---------|
| Activación | `intencion === "rag_documentos"` o clasificador LLM |
| Componentes | HTTP Request → API RAG → nodo LLM |
| Modelo | Sí, **solo** con contexto recuperado |

**Secuencia:**

```
HTTP Request — POST /api/rag/query
  Body: { "pregunta": "{{ $json.pregunta_original }}", "top_k": 5 }
    ↓
Respuesta: { "contexto": "...", "fragmentos": [...] }
    ↓
LLM — Prompt respuesta RAG (sección 8)
    ↓
Enviar respuesta al canal
```

La API RAG ejecuta embedding de la pregunta, búsqueda en **pgvector** sobre `document_chunks` y devuelve texto concatenado en `contexto`. El modelo **no** debe responder sin ese campo poblado.

---

### 6.8 Rama desconocido

| Aspecto | Detalle |
|---------|---------|
| Activación | Fallback del Switch |
| Respuesta por defecto | Ver abajo |
| IA opcional | Clasificador LLM (sección 7) solo si el proyecto lo habilita |

**Mensaje estándar:**

> No tengo suficiente información para responder eso. Puedes preguntarme sobre cursos, calendario, ruta CCD, noticias o historial académico.

**Mejora continua:** registrar en PostgreSQL (`preguntas_sin_resolver`) el par `pregunta_original`, `intencion`, `canal`, `timestamp` para ampliar reglas FAQ.

---

## 7. Prompt para clasificador LLM

**Uso:** rama opcional cuando `intencion === "desconocido"` y se desea una segunda pasada antes de RAG o mensaje genérico.  
**Nodo:** OpenAI / Azure OpenAI / otro — temperatura baja, máximo tokens mínimo.

```
Eres un clasificador de intención para el chatbot del Centro de Competencias Digitales de la UNAB.

Clasifica la pregunta del usuario en una sola de estas categorías:

- faq_directa
- calendario
- cursos_estudiante
- oferta_cursos
- noticias
- rag_documentos
- saludo
- fuera_de_alcance

Pregunta:
{{ $json.pregunta_original }}

Reglas:
- Si pregunta por fechas, inscripciones, inicio, cierre o prueba diagnóstica: calendario.
- Si pregunta por cursos realizados, historial o avance personal: cursos_estudiante.
- Si pregunta por cursos disponibles, categorías o pilares: oferta_cursos.
- Si pregunta por noticias, convocatorias o nuevos cursos: noticias.
- Si pregunta por definiciones institucionales, insignia, requisitos, duración o documentos oficiales: rag_documentos.
- Si saluda: saludo.
- Si no tiene relación con la UNAB, CCD o competencias digitales: fuera_de_alcance.

Responde únicamente con el nombre de la categoría.
```

**Implementación en n8n:** salida del LLM → **Set** `intencion` → reconectar al **Switch** o a sub-workflow por intención. Si la categoría es `fuera_de_alcance`, usar prompt de la sección 9.

---

## 8. Prompt para respuesta RAG

**Uso:** nodo LLM después de la API RAG, rama `rag_documentos`.

```
Eres el asistente virtual del Centro de Competencias Digitales de la Universidad Autónoma de Bucaramanga.

Responde la pregunta del estudiante usando únicamente el contexto proporcionado.

Pregunta del estudiante:
{{ $json.pregunta_original }}

Contexto recuperado:
{{ $json.contexto }}

Instrucciones:
- Responde claro, breve y de forma institucional.
- No inventes fechas, cursos, requisitos ni certificaciones.
- Si el contexto no contiene la respuesta, di:
  "No tengo información suficiente en los documentos disponibles para responder con seguridad."
- Máximo 2 párrafos.
```

---

## 9. Prompt para fuera de alcance

**Uso:** cuando el clasificador LLM devuelve `fuera_de_alcance` o reglas detectan temática ajena al CCD.

```
La pregunta del usuario no corresponde al Centro de Competencias Digitales, la UNAB, cursos, calendario, estudiantes, noticias o competencias digitales.

Responde amablemente:
"Por ahora solo puedo ayudarte con información del Centro de Competencias Digitales, cursos, calendario, noticias y consultas académicas relacionadas."
```

Puede implementarse como **respuesta fija** sin llamar al modelo; el prompt sirve si se desea tono uniforme vía LLM con temperatura 0.

---

## 10. Workflow separado para scraping

**Nombre:** `CCD - Scraper noticias oficiales`  
**Relación con el chatbot:** alimenta datos; **no** se ejecuta por cada mensaje de usuario.

```
Cron (diario, ej. 06:00)
        ↓
HTTP Request — páginas oficiales UNAB / CCD
        ↓
HTML / Code — Extraer títulos, fechas, enlaces, descripción
        ↓
PostgreSQL — Comparar con noticias existentes (hash o URL)
        ↓
INSERT solo registros nuevos
        ↓
UPDATE activo = true, disponible_chatbot = true
```

| Razón | Explicación |
|-------|-------------|
| Latencia | El usuario no espera descarga y parseo de sitios externos |
| Estabilidad | Sitios institucionales pueden cambiar estructura HTML |
| Costo | Evita HTTP repetitivos y procesamiento en cada consulta |
| Consistencia | El chatbot lee siempre el mismo esquema en PostgreSQL |

---

## 11. Base de datos relacionada

### 11.1 Estrategia de datos

- **Fase inicial:** usar la base provista por el profesor cuando esté disponible para datos académicos reales o sintéticos.  
- **Mientras tanto:** mantener instancia **PostgreSQL + pgvector** del proyecto CCD en la VM (Coolify), separada de la base interna de n8n.

### 11.2 Esquema lógico (referencia)

| Área | Tablas / objetos | Uso en el flujo |
|------|------------------|-----------------|
| RAG | `documentos`, `document_chunks`, embeddings vectoriales | API RAG + rama `rag_documentos` |
| Académico | `cursos_ccd`, `calendario_ccd` | Oferta y calendario |
| Estudiantes | `estudiantes_sinteticos`, `matriculas` | Cursos realizados |
| Noticias | `noticias_ccd` | Rama noticias |
| Mejora | `preguntas_sin_resolver` | Registro de `desconocido` |

### 11.3 Separación de bases

| Base | Contenido |
|------|-----------|
| n8n (interna) | Credenciales, ejecuciones, workflows |
| CCD PostgreSQL | Datos institucionales, vectores, logs de preguntas |

No mezclar credenciales ni tablas de negocio en la base de n8n.

---

## 12. Buenas prácticas

| # | Práctica |
|---|----------|
| 1 | No usar IA para saludos ni FAQ con `respuesta_directa`. |
| 2 | No consultar RAG si la pregunta ya tiene respuesta en reglas o SQL. |
| 3 | No hacer scraping en tiempo real desde el flujo conversacional. |
| 4 | No inventar fechas, cursos, requisitos ni certificaciones. |
| 5 | Responder de forma breve (especialmente en Telegram). |
| 6 | Priorizar documentos y datos oficiales cargados en PostgreSQL. |
| 7 | Registrar preguntas `desconocido` para ampliar el Code de intención. |
| 8 | Mantener separadas la base de n8n y la base del proyecto CCD. |
| 9 | Unificar normalización de texto antes de cualquier regla o consulta. |
| 10 | Limitar `top_k` en RAG (3–5 fragmentos) para controlar tokens. |
| 11 | Usar variables de entorno en Coolify para tokens de Telegram, DB y API RAG. |
| 12 | Versionar workflows n8n (export JSON) junto a este documento. |

---

## 13. Versión inicial del flujo (implementación por fases)

### 13.1 Fase 1 — MVP (implementar primero)

```
Telegram Trigger
        ↓
Code — Normalizar pregunta
        ↓
Code — Detectar intención rápida
        ↓
Switch — Intención
        ├── faq_directa  → {{ $json.respuesta_directa }}
        ├── saludo       → {{ $json.respuesta_directa }}
        └── desconocido  → mensaje estándar
        ↓
Telegram Send Message
```

**Objetivo de la fase 1:** validar conectividad, normalización, reglas FAQ y respuestas sin costo de modelo.

### 13.2 Fase 2 — Datos estructurados

Agregar ramas:

- `calendario` → PostgreSQL  
- `oferta_cursos` → PostgreSQL  
- `cursos_estudiante` → PostgreSQL + solicitud de código  

### 13.3 Fase 3 — Contenido dinámico y documental

Agregar:

- `noticias` → PostgreSQL (y workflow scraper en paralelo)  
- `rag_documentos` → API RAG + LLM  

### 13.4 Fase 4 — Multicanal y opcionales

Agregar:

- Webhook Web Chat (convergencia con Telegram)  
- Clasificador LLM en `desconocido` (opcional)  
- Registro de `preguntas_sin_resolver`  

### 13.5 Roadmap resumido

| Fase | Ramas | IA |
|------|-------|-----|
| 1 | FAQ, saludo, desconocido | No |
| 2 | + calendario, oferta, cursos estudiante | No |
| 3 | + noticias, RAG | Solo RAG |
| 4 | + web chat, clasificador opcional | Mínima |

---

## 14. Resultado esperado

Al implementar este diseño en n8n se obtiene:

1. **Menor consumo del modelo:** la mayoría de mensajes se resuelven con Code, Switch y SQL.  
2. **Mayor velocidad:** respuestas FAQ y saludos en milisegundos, sin esperar embedding ni generación.  
3. **Chatbot modular:** cada intención es una rama independiente, fácil de probar y extender.  
4. **Alineación institucional:** RAG y prompts acotados a documentos oficiales del CCD.  
5. **Operación mantenible:** scraping y RAG desacoplados del camino crítico de cada mensaje.

Este documento es la **guía de referencia** para construir el workflow `CCD - Chatbot flujo principal` y el workflow auxiliar `CCD - Scraper noticias oficiales` en n8n, desplegados vía Coolify sobre la VM de Azure del proyecto UNAB.

---

*Fin del documento — Diseño flujo n8n Chatbot CCD UNAB v1.0*
