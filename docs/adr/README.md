# Decisiones de arquitectura (ADR)

Una decision por archivo. Se abren cuando empiece el codigo, en Fase 1.

## Formato

```
# ADR-NN · <titulo en lenguaje natural>

**Estado:** aceptado · **Fecha:** YYYY-MM-DD · **Decide:** Gonzalo (MOTRAE)

## Contexto
Que problema habia y que restricciones existian.

## Decision
Que se decidio, en positivo.

## Consecuencias
Que gana y que pierde el proyecto con esto. Lo que se pierde tambien se escribe.
```

## Reglas

- Cuando una decision cambie, **no se edita el ADR viejo**: se marca como superado y se abre uno nuevo que lo reemplaza. El ADR viejo es historia, y la historia sirve.
- Las decisiones estructurales que ya estan tomadas viven en `docs/motsport/03_ARQUITECTURA.md` con la nomenclatura D-1 a D-9. Cuando alguna cambie, ahi es donde nace su ADR.

## Indice

- [ADR-01 · Las herramientas de desarrollo se versionan en el repositorio, no en la maquina](ADR-01-herramientas-locales-versionadas.md) — Supabase CLI, pnpm, Node y Python quedan declarados en el repo. Nace de dos instalaciones fallidas y un falso positivo de `python.exe`.
