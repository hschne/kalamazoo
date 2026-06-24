/** @type {import('stylelint').Config} */
export default {
  extends: ['stylelint-config-standard', 'stylelint-config-html'],
  plugins: ['stylelint-no-unsupported-browser-features'],
  rules: {
    'plugin/no-unsupported-browser-features': null,
    'at-rule-no-unknown': null,
    'import-notation': 'string',
    'custom-property-pattern': null,
    'declaration-property-value-no-unknown': null,
  },
}
