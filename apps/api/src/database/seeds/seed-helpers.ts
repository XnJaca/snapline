import { DataSource } from 'typeorm';
import { newId } from '../../common/entities/base.entity';

/**
 * Devuelve el id de la fila que ya está, o la crea.
 *
 * El seed corre muchas veces sobre la misma base —después de una migración, al
 * volver a un branch—, así que insertar a ciegas lo vuelve inservible: falla en
 * la primera fila y no llega a las demás.
 *
 * Busca por **clave natural** y no por id, porque el id se genera en cada
 * corrida y nunca coincidiría con el de la vez anterior.
 */
export async function obtenerOCrear(
  ds: DataSource,
  tabla: string,
  buscarPor: string,
  claves: unknown[],
  insertar: (id: string) => Promise<unknown>,
): Promise<string> {
  const filas = (await ds.query(
    `SELECT id FROM ${tabla} WHERE ${buscarPor} LIMIT 1`,
    claves,
  )) as Array<{ id: string }>;
  if (filas[0]) return filas[0].id;

  const id = newId();
  await insertar(id);
  return id;
}
