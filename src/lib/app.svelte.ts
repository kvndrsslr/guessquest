import { CurrentUser } from '#lib/CurrentUser.svelte.js';
import { RoomType, NetworkClient } from '#lib/network.js';

export type Choice = string | number | [number, number] | null;

export type UserData = {
	id: number;
	name: string;
	hero: number;
	choice: Choice;
	spectator?: boolean;
	edited?: boolean;
};

export type RoomData = {
	connected: boolean;
	quest: number;
	roomType: RoomType;
	revealed: boolean;
	otherUsers: UserData[];
	spectators: UserData[];
};

// Carried over from the landing form by the room page's join flow; consumed once so
// direct-link joins start on StoryPoints and let the server's Sync correct them.
const initialRoomType =
	sessionStorage.getItem('roomType') === '1' ? RoomType.PersonDays : RoomType.StoryPoints;
sessionStorage.removeItem('roomType');

export const room: RoomData = $state({
	connected: false,
	quest: 0,
	roomType: initialRoomType,
	revealed: false,
	otherUsers: [],
	spectators: []
});

async function getWebSocketAddress() {
	const publicUrl = `wss://${window.location.host}/ws`;

	if (window.location.hostname !== 'localhost' && window.location.hostname !== '127.0.0.1') {
		return publicUrl;
	}

	const localhostUrl = `ws://localhost:48377/ws`;

	const url = new Promise<string>((resolve) => {
		const testSocket = new WebSocket(localhostUrl);
		testSocket.onerror = () => {
			resolve(publicUrl);
		};
		testSocket.onopen = () => {
			setTimeout(() => {
				testSocket.close();
			}, 250);
			resolve(localhostUrl);
		};
	});

	return url;
}

const net = new NetworkClient(await getWebSocketAddress());

export const currentUser = new CurrentUser(net, room);

export function poke(user: number, pokedWith: string) {
	// TODO implement poking visually
	net.sendPoke({
		poked: user,
		pokedWith
	});
}

export function reveal() {
	room.revealed = true;
	net.sendReveal();
}

export function newQuest(roomType: RoomType) {
	room.quest += 1;
	room.roomType = roomType;
	room.revealed = false;
	currentUser.resetChoice();

	net.sendResetRoom({
		roomType: room.roomType
	});
}
