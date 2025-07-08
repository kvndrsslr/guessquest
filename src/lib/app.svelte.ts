import { page } from '$app/state';
import { RoomType, NetworkClient } from '$lib/network';

export type Choice = string | number | [number, number] | null;

export type UserData = {
	id: number;
	name: string;
	hero: number;
	choice: Choice;
	spectator?: boolean;
	edited?: boolean;
};

type RoomData = {
	connected: boolean;
	quest: number;
	roomType: RoomType;
	revealed: boolean;
	otherUsers: UserData[];
};

export const room: RoomData = $state({
	connected: false,
	quest: 0,
	roomType: RoomType.StoryPoints,
	revealed: false,
	otherUsers: []
});

async function getWebSocketAddress() {
	const publicUrl = `wss://ws-guessquest.kxfin.xyz`;

	if (window.location.hostname !== 'localhost' && window.location.hostname !== '127.0.0.1') {
		return publicUrl;
	}

	const localhostUrl = `ws://localhost:60355`;

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

class CurrentUser {
	id: number = $state(0);
	spectator: boolean = $derived(page.params.mode === 'spectator');
	#name: string = $state('Unknown Hero');
	#hero: number = $state(0);
	#choice: Choice | null = $state(null);
	edited = $state(false);

	constructor() {
		const name = window.localStorage.getItem('name') ?? window.sessionStorage.getItem('name');
		this.#name = name ?? this.#name;

		const hero = window.localStorage.getItem('hero') ?? window.sessionStorage.getItem('hero');
		this.#hero = hero ? parseInt(hero, 10) : Math.floor(Math.random() * 11.99);
	}

	set name(name: string) {
		this.#name = name;
		if (window.localStorage.getItem('name')) {
			window.localStorage.setItem('name', name);
		}
		window.sessionStorage.setItem('name', name);
		net.sendUpdateUserName({ name: this.#name });
	}

	get name(): string {
		return this.#name;
	}

	cycleHero(): void {
		this.hero = (this.#hero + 1) % 12;
	}

	set hero(hero: number) {
		this.#hero = hero;
		if (window.localStorage.getItem('name')) {
			window.localStorage.setItem('hero', hero.toString());
		}
		window.sessionStorage.setItem('hero', hero.toString());
		net.sendUpdateUserHero({ hero: this.#hero });
	}

	get hero(): number {
		return this.#hero;
	}

	set choice(choice: Choice) {
		if (!room.revealed && this.#choice === choice) {
			this.#choice = null;
		} else if (room.revealed && this.#choice === choice) {
			return;
		} else {
			this.edited = room.revealed;
			this.#choice = choice;
		}
		net.sendUpdateUserChoice({ choice: this.#choice });
	}

	resetChoice(): void {
		this.#choice = null;
		this.edited = false;
	}

	get choice(): Choice {
		return this.#choice;
	}

	toUserData(): UserData {
		return {
			id: this.id,
			name: this.#name,
			hero: this.#hero,
			choice: this.#choice,
			spectator: this.spectator,
			edited: this.edited
		};
	}
}

export const currentUser = new CurrentUser();

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

export function newQuest(roomType?: RoomType) {
	room.quest += 1;
	room.roomType = roomType ?? RoomType.StoryPoints;
	room.revealed = false;
	currentUser.resetChoice();

	net.sendResetRoom({
		roomType: room.roomType
	});
}
