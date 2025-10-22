module.exports = {
  '*.{ts,tsx,js,jsx}': ['eslint --fix', 'prettier --write'],
  '*.{json,md,yml,yaml}': ['prettier --write'],
  '*.sol': ['prettier --write --plugin=prettier-plugin-solidity'],
  '*.{ts,tsx}': () => 'tsc --noEmit',
};