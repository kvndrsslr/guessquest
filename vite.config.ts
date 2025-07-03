import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
import devtoolsJson from 'vite-plugin-devtools-json';

export default defineConfig({
	server: {
		host: '127.0.0.1'
	},
	plugins: [sveltekit(), devtoolsJson()],
	build: {
		target: 'esnext'
	}
});
