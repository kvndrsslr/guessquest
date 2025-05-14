import polka from 'polka';
import { useWebSocketServer } from './socket.js';

const app = polka();

const handler = './handler.js';
app.use((await import(handler)).handler);

app.listen(3000, () => {
	console.log('listening on port 3000');
});

useWebSocketServer(app.server);
