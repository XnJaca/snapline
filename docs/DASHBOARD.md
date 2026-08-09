---
id: DASHBOARD
title: "Dashboard — Snapline"
type: dashboard
tags:
  - dashboard
---

# 📊 Dashboard Snapline

Estado en vivo. Todas las tablas se actualizan solas cuando cambia el frontmatter
de un archivo. Requiere el plugin **Dataview**.

---

## 🎯 Producto

**Visión**: [[product/vision|vision]] · **Roadmap**: [[product/roadmap|roadmap]] · **Modelo**: [[domain/README|dominio]] · **Decisiones**: [[DECISIONES]]

---

## 📋 Specs

### Todos, por estado

```dataview
TABLE WITHOUT ID
  link(file.path, default(aliases[0], file.folder)) AS "Spec",
  platform AS "Plataforma",
  status AS "Estado",
  frente AS "Frente",
  updated AS "Actualizado"
FROM "specs"
WHERE type = "spec"
SORT status ASC, updated DESC
```

### Conteo por estado

```dataview
TABLE WITHOUT ID
  status AS "Estado",
  length(rows) AS "Cantidad"
FROM "specs"
WHERE type = "spec"
GROUP BY status
```

### Cobertura por frente

Un frente sin specs es un frente que nadie está construyendo.

```dataview
TABLE WITHOUT ID
  frente AS "Frente",
  length(rows) AS "Specs",
  join(sort(rows.status), ", ") AS "Estados"
FROM "specs"
WHERE type = "spec"
GROUP BY frente
```

---

## 🏛️ ADRs

### Aceptados

```dataview
TABLE WITHOUT ID
  link(file.path, default(aliases[0], file.folder)) AS "ADR",
  created AS "Fecha",
  related_specs AS "Specs impactados"
FROM "adr"
WHERE type = "adr" AND status = "aceptado"
SORT created DESC
```

### Pendientes de aceptar

```dataview
LIST
FROM "adr"
WHERE type = "adr" AND status = "propuesto"
SORT file.ctime DESC
```

---

## 🧩 Dominio

```dataview
TABLE WITHOUT ID
  link(file.path, default(aliases[0], title)) AS "Agregado",
  status AS "Estado",
  related_specs AS "Specs que lo tocan"
FROM "domain"
WHERE type = "domain"
SORT status ASC, title ASC
```

---

## 🧹 Deuda técnica

```dataview
TABLE WITHOUT ID
  link(file.path, default(aliases[0], title)) AS "Deuda",
  severity AS "Severidad",
  status AS "Estado",
  trigger AS "Trigger",
  updated AS "Actualizado"
FROM "tech-debt"
WHERE type = "tech-debt"
SORT status ASC, severity DESC
```

### Activa (duele hoy)

```dataview
LIST
FROM "tech-debt"
WHERE type = "tech-debt" AND status = "activa"
SORT severity DESC
```

---

## 📅 Actividad reciente

```dataview
TABLE WITHOUT ID
  link(file.path, default(aliases[0], default(title, file.name))) AS "Archivo",
  type AS "Tipo",
  status AS "Estado",
  file.mtime AS "Modificado"
WHERE type != null
SORT file.mtime DESC
LIMIT 10
```

---

## 🔎 Por hacer

```dataview
TASK
FROM "specs" OR "product" OR "domain" OR "tech-debt"
WHERE !completed
GROUP BY file.link
```

---

## 🚨 Alertas

### Specs sin dominio vinculado

Implementan algo pero no declaran qué agregados tocan. Riesgo de inconsistencia
con el modelo.

```dataview
LIST
FROM "specs"
WHERE type = "spec" AND (domain = null OR length(domain) = 0) AND status != "archivado"
```

### Specs sin `goal` — o con un goal que no se puede verificar

El `goal` es contra lo que el `code-reviewer` valida lo implementado. Sin él, la
revisión no tiene ancla y el spec no se puede cerrar.

```dataview
LIST
FROM "specs"
WHERE type = "spec" AND (goal = null OR goal = "")
```

Estos arrancan con un verbo de intención en vez de describir un estado verificable.
Revisar a mano:

```dataview
TABLE WITHOUT ID
  link(file.path, default(aliases[0], file.folder)) AS "Spec",
  goal AS "Goal"
FROM "specs"
WHERE type = "spec" AND goal != null
  AND (contains(lower(goal), "mejorar") OR contains(lower(goal), "implementar")
    OR contains(lower(goal), "agregar") OR contains(lower(goal), "optimizar"))
```

### Specs mobile sin comportamiento offline declarado

Funcionar sin señal es requisito no negociable. Un spec mobile que no dice qué
pasa sin red está incompleto.

```dataview
LIST
FROM "specs/mobile"
WHERE type = "spec" AND !contains(file.content, "sin señal")
```

### Specs aprobados sin implementar hace más de 14 días

```dataview
TABLE status, updated
FROM "specs"
WHERE type = "spec" AND status = "aprobado"
  AND date(updated) < date(today) - dur(14 days)
SORT updated ASC
```

### Deuda sin trigger definido

Deuda sin trigger termina olvidada. Corregir.

```dataview
LIST
FROM "tech-debt"
WHERE type = "tech-debt"
  AND (trigger = null OR trigger = "")
  AND status != "resuelta" AND status != "descartada"
```
