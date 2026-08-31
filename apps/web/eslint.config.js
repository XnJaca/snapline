// @ts-check
const eslint = require('@eslint/js');
const tseslint = require('typescript-eslint');
const angular = require('angular-eslint');

module.exports = tseslint.config(
  {
    files: ['**/*.ts'],
    extends: [
      eslint.configs.recommended,
      ...tseslint.configs.recommended,
      ...angular.configs.tsRecommended,
    ],
    processor: angular.processInlineTemplates,
    rules: {
      // Los prefijos del proyecto: `sl-` en selectores de elemento, `sl` en atributo.
      '@angular-eslint/directive-selector': [
        'error',
        { type: 'attribute', prefix: 'sl', style: 'camelCase' },
      ],
      '@angular-eslint/component-selector': [
        'error',
        { type: 'element', prefix: 'sl', style: 'kebab-case' },
      ],
      // Regla 21: tres archivos, siempre. Cero declaraciones inline — ni una línea
      // de template ni de estilos dentro del `.ts`. Es la regla que en ACDEMIC se
      // saltó "porque el componente era chiquito", así que acá la verifica el lint
      // y no la memoria de quien revisa.
      '@angular-eslint/component-max-inline-declarations': [
        'error',
        { template: 0, styles: 0, animations: 0 },
      ],
      '@angular-eslint/prefer-standalone': 'error',
      '@angular-eslint/use-component-view-encapsulation': 'off',
    },
  },
  {
    files: ['**/*.html'],
    extends: [...angular.configs.templateRecommended, ...angular.configs.templateAccessibility],
    rules: {},
  },
);
