import js from "@eslint/js";
import compat from "eslint-plugin-compat";
import globals from "globals";

export default [
  {
    ignores: ["node_modules/**", "public/**", "tmp/**", "vendor/**"],
  },
  js.configs.recommended,
  compat.configs["flat/recommended"],
  {
    files: ["app/javascript/**/*.js"],
    languageOptions: {
      globals: {
        ...globals.browser,
      },
    },
  },
];
