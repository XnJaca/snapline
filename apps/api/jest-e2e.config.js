module.exports = {
  moduleFileExtensions: ['js', 'json', 'ts'],
  rootDir: '.',
  testRegex: 'test/.*\\.e2e-spec\\.ts$',
  transform: { '^.+\\.ts$': 'ts-jest' },
  testEnvironment: 'node',
  testTimeout: 30000,
  maxWorkers: 1,
  // El pool de Postgres y el contexto de typeorm-transactional quedan vivos tras
  // app.close(). Es ruido del runner, no de la app.
  forceExit: true,
};
