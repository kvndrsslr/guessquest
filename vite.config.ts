import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig, type ViteDevServer } from 'vite';
import devtoolsJson from 'vite-plugin-devtools-json';
import { useWebSocketServer } from './socket';

const webSocketServer = {
	name: 'webSocketServer',
	configureServer(server: ViteDevServer) {
		if (!server.httpServer) return;
		useWebSocketServer(server.httpServer);
	}
};

export default defineConfig({
	server: {
		host: '127.0.0.1'
	},
	plugins: [sveltekit(), devtoolsJson(), webSocketServer],
	build: {
		target: 'esnext'
	}
});
