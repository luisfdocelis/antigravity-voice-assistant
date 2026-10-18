---
name: "code-review-runner"
description: "Activar cuando el usuario solicite revisar codigo, hacer review de PR, auditar cambios o evaluar riesgos de regresion. Prioriza bugs, riesgos, regresiones de comportamiento y pruebas faltantes."
argument-hint: "Ruta, modulo, PR o alcance a revisar"
---

# Code Review Runner Skill

Esta skill estandariza revisiones de codigo tecnicas y accionables, centradas en calidad funcional y riesgo.

## Cuando usar

Activa esta skill cuando el usuario pida:
- revision de codigo
- review de pull request
- auditoria de cambios
- deteccion de riesgos o regresiones
- validacion de pruebas faltantes

## Resultado esperado

La salida final debe incluir, en este orden:
1. Hallazgos primero, ordenados por severidad.
2. Preguntas abiertas o supuestos (si aplica).
3. Resumen breve de cambios revisados.
4. Riesgos residuales y cobertura de pruebas.

## Flujo de revision

1. Definir alcance exacto.
- Determinar si la revision aplica a archivos cambiados, modulo completo o todo el repositorio.
- Si el alcance es ambiguo, asumir cambios del branch actual y dejarlo explicito.

2. Recolectar evidencia.
- Revisar diffs y archivos relevantes.
- Verificar contratos de API, validaciones, manejo de errores y casos borde.
- Revisar consistencia con arquitectura y convenciones del repositorio.

3. Buscar problemas de alto impacto primero.
- Correctitud: bugs, null checks, condiciones de carrera, errores de logica.
- Seguridad: validacion de entrada, exposicion de datos, secretos, authz/authn.
- Regresion funcional: cambios de comportamiento no intencionales.

4. Evaluar mantenibilidad y operacion.
- Complejidad innecesaria, deuda tecnica introducida, acoplamiento excesivo.
- Observabilidad: logs, mensajes de error, trazabilidad para soporte.

5. Validar pruebas.
- Confirmar si hay pruebas para comportamiento nuevo o corregido.
- Marcar vacios de cobertura en rutas criticas.
- Verificar que el set de pruebas ejecutado sea razonable para el alcance.

6. Redactar hallazgos con formato estricto.
- Cada hallazgo debe incluir: severidad, impacto, evidencia (archivo/linea), y recomendacion concreta.
- No mezclar hallazgos con sugerencias opcionales.

7. Cerrar con veredicto.
- Si hay hallazgos: indicar que deben corregirse antes de merge (cuando aplique).
- Si no hay hallazgos: declararlo explicitamente y listar riesgos residuales o huecos de prueba.

## Regla de severidad

Usa esta taxonomia:
- Alta: puede romper funcionalidad critica, seguridad o datos.
- Media: riesgo funcional moderado o deuda relevante a corto plazo.
- Baja: mejora recomendable sin riesgo inmediato de produccion.

## Criterios de calidad de la revision

La revision se considera completa solo si:
1. Incluye evidencia verificable por archivo/linea para cada hallazgo.
2. Explica el impacto real en usuario, negocio o operacion.
3. Propone accion concreta y minima para corregir.
4. Declara explicitamente cuando no se encontraron hallazgos.
5. Reporta riesgos residuales y brechas de prueba.

## Prompt sugerido

- "Revisa este PR con foco en regresiones y seguridad"
- "Haz code review de apps/api con severidad y evidencia"
- "Audita los cambios de frontend y dime si faltan pruebas"
