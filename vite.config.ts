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
				.map((m) => m[0])
				.toArray();
			return `export default JSON.parse('${JSON.stringify(urls)}');`;
		}
	};
}

export default defineConfig({
	plugins: [sveltekit(), devtoolsJson(), cats()],
	build: {
		target: 'esnext'
	}
});
