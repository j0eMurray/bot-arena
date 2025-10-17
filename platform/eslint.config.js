// eslint.config.js (Flat Config para ESLint v9)
import js from "@eslint/js";
import tseslint from "typescript-eslint";
import prettier from "eslint-config-prettier";

export default [
  // Archivos/paths a ignorar por ESLint
  {
    ignores: [
      "**/node_modules/**",
      "**/dist/**",
      "**/build/**",
      ".devcontainer/**",
      "infra/**",
      "apps/flutter_app/**"
    ],
  },

  // Reglas base para JS
  js.configs.recommended,

  // Reglas recomendadas para TypeScript (sin type-checking)
  ...tseslint.configs.recommended,

  // Ajustes comunes para archivos .ts
  {
    files: ["**/*.ts"],
    languageOptions: {
      parser: tseslint.parser,
      parserOptions: {
        ecmaVersion: "latest",
        sourceType: "module",
      },
    },
    rules: {
      // Ejemplos: relaja/ajusta a tu gusto
      "no-console": "off",
    },
  },

  // Desactiva reglas que chocan con Prettier (mantén a Prettier como formateador)
  prettier,
];
