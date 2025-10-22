import { defineConfig } from 'tsup';

export default defineConfig({
  entry: {
    index: 'src/index.ts',
    'modules/accounts/index': 'src/modules/accounts/index.ts',
    'modules/paymaster/index': 'src/modules/paymaster/index.ts',
    'modules/nft/index': 'src/modules/nft/index.ts',
    'modules/tipping/index': 'src/modules/tipping/index.ts',
    'modules/automation/index': 'src/modules/automation/index.ts',
    'modules/abstract/index': 'src/modules/abstract/index.ts',
  },
  format: ['cjs', 'esm'],
  dts: true,
  sourcemap: true,
  clean: true,
  splitting: false,
  treeshake: true,
  minify: false,
  target: 'es2022',
  outDir: 'dist',
});