---
name: "refactor-optimizer"
description: "Limpieza de código, aplicación de principios SOLID, reducción de deuda técnica y mejora de rendimiento."
---
# Refactor Optimizer Skill

## Cuándo usar
Activar para tareas en ramas `refactor/` o `perf/` para modernizar código o mejorar complejidad algorítmica.

## Reglas
1. Modificar estructura sin alterar el comportamiento funcional observable.
2. Detectar "code smells" (funciones largas, acoplamiento fuerte, valores mágicos).
3. Mejorar la eficiencia (Notación Big O) en cuellos de botella de CPU o Memoria.
4. Ejecutar estrictamente `verify-runner` para garantizar que ninguna prueba existente se rompa.
