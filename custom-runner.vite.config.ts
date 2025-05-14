import { defineConfig } from 'vite';

export default defineConfig({
	ssr: {
		external: ['./handler.js'],
		noExternal: true
	},
	build: {
		outDir: 'build',
		target: 'esnext',
		emptyOutDir: false,
		ssr: true,
		lib: {
			entry: 'run.js',
			formats: ['es']
		},
		rollupOptions: {
			output: {
				entryFileNames: 'index.js'
			}
		}
	}
});
