import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'vitest/config';
import { playwright } from '@vitest/browser-playwright';
import { sveltekit } from '@sveltejs/kit/vite';
import AutoImport from 'unplugin-auto-import/vite';
import { customImport } from './src/lib/auto-import/global-lib.ts';

export default defineConfig({
	plugins: [
		tailwindcss(),
		sveltekit(),
		AutoImport({
			include: [/\.svelte$/],
			imports: [...customImport],
			dts: './auto-imports.d.ts',
			dtsMode: 'append'
		})
	],
	ssr: {
		// Bundle these packages into the SSR bundle at build time instead of
		// loading them from node_modules at runtime. This fixes two issues:
		// 1. EMFILE (too many open files) — bundled = single files, not thousands
		// 2. @walletconnect/logger named export error — bundler handles CJS→ESM interop
		noExternal: [/^@walletconnect\//, /^@reown\//, /^@wagmi\//, 'wagmi', 'viem']
	},
	test: {
		expect: { requireAssertions: true },
		projects: [
			{
				extends: './vite.config.ts',
				test: {
					name: 'client',
					browser: {
						enabled: true,
						provider: playwright(),
						instances: [{ browser: 'firefox', headless: true }]
					},
					include: ['tests/**/*.svelte.{test,spec}.{js,ts}'],
					exclude: []
				}
			},

			{
				extends: './vite.config.ts',
				test: {
					name: 'server',
					environment: 'node',
					include: ['tests/**/*.{test,spec}.{js,ts}'],
					exclude: ['tests/**/*.svelte.{test,spec}.{js,ts}']
				}
			}
		]
	}
});
