# @snapline/contracts

Tipos del contrato del API para los consumidores de TypeScript (Angular, Astro).

**No se editan a mano.** Se generan desde `openapi.json`, que emite el API a partir
de sus DTOs:

```bash
pnpm contracts:generate    # desde la raíz
```

Flutter no consume este paquete: genera sus modelos Dart desde el mismo
`openapi.json`. Ver ADR-0007.
