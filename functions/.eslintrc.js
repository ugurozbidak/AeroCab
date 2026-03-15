module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    ecmaVersion: 2020,
  },
  extends: [
    "eslint:recommended",
    "plugin:promise/recommended",
  ],
  rules: {
    "promise/always-return": "off",
  },
};
