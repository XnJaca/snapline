import { TypeOrmModuleOptions } from '@nestjs/typeorm';

// Runtime: rol restringido, RLS aplica. El esquema solo cambia por migración.
export const databaseConfig = (): TypeOrmModuleOptions => ({
  type: 'postgres',
  host: process.env.DB_HOST ?? 'localhost',
  port: Number(process.env.DB_PORT ?? 5544),
  database: process.env.DB_NAME ?? 'snapline',
  username: process.env.DB_USERNAME ?? 'snapline_app',
  password: process.env.DB_PASSWORD ?? 'snapline_dev',
  // Glob en vez de autoLoadEntities: este último solo carga lo registrado con
  // forFeature, y las relaciones apuntan a entities de módulos que aún no existen.
  entities: [__dirname + '/../**/*.entity{.ts,.js}'],
  synchronize: false,
  dropSchema: false,
  migrationsRun: false,
  logging: ['error', 'warn'],
});
