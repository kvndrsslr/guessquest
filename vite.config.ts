import adapter from '@sveltejs/adapter-static';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig, type Plugin } from 'vite';
import devtoolsJson from 'vite-plugin-devtools-json';

/**
 * Always have up to date cats
 */
function cats(): Plugin {
	const virtualModuleId = 'virtual:cats';
	const resolvedVirtualModuleId = '\0' + virtualModuleId;
	return {
		name: 'cats',
		resolveId(id) {
			if (id === virtualModuleId) {
				return resolvedVirtualModuleId;
			}
		},
		async load(id) {
			if (id !== resolvedVirtualModuleId) return;
			const response = await fetch('https://edgecats.net/all');
			const text = await response.text();
			const urls = text
				.matchAll(/https?:\/\/moar\..*?\.gif/g)
				// the index links the gifs over http, but that origin 404s; https serves them
				.map((m) => m[0].replace(/^http:/, 'https:'))
				.toArray();
			return `export default JSON.parse('${JSON.stringify(urls)}');`;
		}
	};
}

export default defineConfig({
	plugins: [
		sveltekit({
			preprocess: vitePreprocess(),
			compilerOptions: { runes: true },
			output: { bundleStrategy: 'split' },
			adapter: adapter({ pages: 'src/server/_static', assets: 'src/server/_static' }),
			router: { type: 'hash' }
		}),
		devtoolsJson(),
		cats()
	],
	build: { target: 'esnext' }
});
