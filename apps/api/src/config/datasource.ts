import 'reflect-metadata';
import { config } from 'dotenv';
import { DataSource } from 'typeorm';

config();

// CLI: migraciones y seeds. Usa el rol owner, que bypassa RLS. ADR-0006.
export default new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST ?? 'localhost',
  port: Number(process.env.DB_PORT ?? 5544),
  database: process.env.DB_NAME ?? 'snapline',
  username: process.env.DB_MIGRATION_USERNAME ?? 'snapline_migrator',
  password: process.env.DB_MIGRATION_PASSWORD ?? 'snapline_dev',
  entities: [__dirname + '/../**/*.entity{.ts,.js}'],
  migrations: [__dirname + '/../database/migrations/*{.ts,.js}'],
  synchronize: false,
  logging: ['error', 'warn', 'migration'],
});
