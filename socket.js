// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-nocheck
// @todo port backend to zig for production
import { WebSocketServer, WebSocket } from 'ws';

export function useWebSocketServer(server) {
	const wss = new WebSocketServer({
		noServer: true
	});

	const rooms = new Map();

	function getRoomData(sender) {
		const roomId = sender['roomId'];
		const { clients, revealed, quest, questType } = rooms.get(roomId) ?? {
			clients: new Set(),
			revealed: false,
			quest: 0
		};

		return {
			revealed,
			quest,
			questType,
			otherUsers: Array.from(clients)
				.filter((ws) => ws !== sender)
				.map((ws) => ({
					name: ws['name'],
					hero: ws['hero'],
					spectator: ws['spectator'],
					choice: ws['choice'] ?? null
				}))
		};
	}

	function broadcast(roomId, type, data, filterPredicate) {
		rooms.get(roomId)?.clients.forEach((client) => {
			if (client.readyState === WebSocket.OPEN && filterPredicate?.(client) !== false) {
				if (type === 'roomUpdate') {
					data = getRoomData(client);
				}
				client.send(JSON.stringify({ type, ...data }));
			}
		});
	}

	wss.on('connection', function connection(ws) {
		ws.on('error', console.error);

		ws.on('pong', () => {
			ws['isAlive'] = true;
		});

		ws.on('message', function message(data) {
			ws['isAlive'] = true;

			const stringData = data.toString('utf-8'); // Ensure data is a string

			if (typeof stringData !== 'string') {
				console.warn('Received non-string data:', stringData);
				return;
			}
			let parsedData;
			try {
				parsedData = JSON.parse(stringData);
			} catch (e) {
				console.error('Failed to parse JSON:', e);
				return;
			}

			if (parsedData['type'] === 'join') {
				if (ws['roomId'] !== undefined) {
					console.warn('Cannot join twice:', parsedData);
					return;
				}
				if (
					typeof parsedData['name'] !== 'string' ||
					typeof parsedData['roomId'] !== 'string' ||
					typeof parsedData['questType'] !== 'number' ||
					typeof parsedData['hero'] !== 'number'
				) {
					console.warn('Invalid join message:', parsedData);
					return;
				}
				ws['name'] = parsedData['name'];
				ws['roomId'] = parsedData['roomId'];
				ws['hero'] = parsedData['hero'];
				ws['choice'] = parsedData['choice'] ?? null;
				ws['spectator'] = parsedData['spectator'] ?? false;

				if (!rooms.has(ws['roomId'])) {
					rooms.set(ws['roomId'], {
						questType: parsedData['questType'],
						clients: new Set([ws]),
						revealed: false,
						quest: 0
					});
				} else {
					rooms.get(ws['roomId']).clients.add(ws);
				}
				broadcast(ws['roomId'], 'roomUpdate');
				return;
			}

			if (!ws['roomId']) {
				console.warn('Received message before joining room:', parsedData, parsedData['type']);
				return;
			}

			const room = rooms.get(ws['roomId']);

			switch (parsedData['type']) {
				case 'reveal':
					room.revealed = true;
					break;
				case 'newQuest':
					room.revealed = false;
					room.quest++;
					room.questType = parsedData['questType'] ?? room.questType;
					room.clients.forEach((client) => {
						client['choice'] = null; // Reset choices for all clients
					});
					break;
				case 'userUpdate':
					ws['edited'] = room.revealed && parsedData['choice'] !== undefined;
					ws['choice'] = parsedData['choice'] ?? ws['choice'];
					ws['name'] = parsedData['name'] ?? ws['name'];
					ws['hero'] = parsedData['hero'] ?? ws['hero'];
					ws['spectator'] = parsedData['spectator'] ?? ws['spectator'];
					break;
				case 'poke':
					broadcast(
						ws['roomId'],
						'poked',
						{ pokedWith: parsedData['pokedWith'], user: parsedData['user'] },
						(client) => client !== ws
					);
					return;
				// kind of stupid, but lib0/websocket implements it like this.
				// @todo implement reconnect logic ourselves and get rid of lib0/websocket
				case 'ping':
					ws.send(JSON.stringify({ type: 'pong' }));
					return;
				default:
					console.warn('Unknown message type:', parsedData['type']);
					return;
			}

			broadcast(ws['roomId'], 'roomUpdate', (client) => client !== ws);
		});

		ws.on('close', () => {
			if (!ws['roomId']) {
				console.warn('Closed without roomId!');
				return;
			}
			rooms.get(ws['roomId'])?.clients.delete(ws);
			if (rooms.get(ws['roomId'])?.clients.size === 0) {
				rooms.delete(ws['roomId']);
			} else {
				broadcast(ws['roomId'], 'roomUpdate');
			}
		});
	});

	const interval = setInterval(function ping() {
		wss.clients.forEach(function each(ws) {
			if (ws['isAlive'] === false) {
				return ws.terminate();
			}

			ws['isAlive'] = false;
			ws.ping();
		});
	}, 4000);

	wss.on('close', function close() {
		clearInterval(interval);
	});

	server.on('upgrade', (req, socket, head) => {
		if (new URL(req.url, 'http://localhost/').pathname === '/ws') {
			wss.handleUpgrade(req, socket, head, (ws) => {
				wss.emit('connection', ws, req);
			});
		}
	});
}
