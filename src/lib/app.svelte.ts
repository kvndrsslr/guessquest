import { browser } from '$app/environment';
import { page } from '$app/state';
import { WebsocketClient } from 'lib0/websocket';

export enum QuestType {
	Fibonacci = 0,
	PersonDays = 1
}

export type Choice = string | number | [number, number] | null;

export type UserData = {
	name: string;
	hero: number;
	choice: Choice;
	spectator?: boolean;
	edited?: boolean;
};

type RoomData = {
	connected: boolean;
	quest: number;
	questType: QuestType;
	revealed: boolean;
	otherUsers: UserData[];
};

export const room: RoomData = $state({
	connected: false,
	quest: 0,
	questType: QuestType.Fibonacci,
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

const ws = browser ? new WebsocketClient(await getWebSocketAddress()) : undefined;

let firstMessage = true;

ws?.on('connect', () => {
	ws.send({
		type: 'join',
		roomId: page.params.roomId,
		questType: room.questType,
		name: currentUser.name,
		hero: currentUser.hero,
		choice: JSON.stringify(currentUser.choice)
	});
});

// eslint-disable-next-line @typescript-eslint/no-explicit-any
ws?.on('message', (data: any) => {
	if (firstMessage) {
		room.connected = true;
		firstMessage = false;
	}
	if (!data?.type) {
		console.warn('Received message without type:', data);
		return;
	}
	switch (data.type) {
		case 'pong':
			return; // do not respond to pong here
		case 'poke':
			// @todo implement poking
			console.log('Poked', data.user, 'with:', data.pokedWith);
			return;
		case 'roomUpdate':
			if (room.quest !== data.quest) {
				// new quest started
				resetChoice();
			}
			room.quest = data.quest;
			room.questType = data.questType;
			room.revealed = data.revealed;
			room.otherUsers = data.otherUsers.map((user: UserData) => ({
				...user,
				choice: JSON.parse(user.choice as string)
			}));

			return;
	}
});

ws?.on('disconnect', () => {
	room.connected = false;
	firstMessage = true;
});

class CurrentUser {
	spectator: boolean = $derived(browser ? page.params.mode === 'spectator' : false);
	#name: string = $state('Unknown Hero');
	#hero: number = $state(0);
	#choice: Choice | null = $state(null);
	edited = $state(false);

	constructor() {
		if (browser) {
			const name = window.localStorage.getItem('name') ?? window.sessionStorage.getItem('name');
			this.#name = name ?? this.#name;

			const hero = window.localStorage.getItem('hero') ?? window.sessionStorage.getItem('hero');
			this.#hero = hero ? parseInt(hero, 10) : Math.floor(Math.random() * 11.99);
		}
	}

	set name(name: string) {
		this.#name = name;
		if (browser) {
			if (window.localStorage.getItem('name')) {
				window.localStorage.setItem('name', name);
			}
			window.sessionStorage.setItem('name', name);
		}
		this.#sendUpdate();
	}

	get name(): string {
		return this.#name;
	}

	cycleHero(): void {
		this.hero = (this.#hero + 1) % 12;
	}

	set hero(hero: number) {
		this.#hero = hero;
		if (browser) {
			if (window.localStorage.getItem('name')) {
				window.localStorage.setItem('hero', hero.toString());
			}
			window.sessionStorage.setItem('hero', hero.toString());
		}
		this.#sendUpdate();
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
		this.#sendUpdate();
	}

	get choice(): Choice {
		return this.#choice;
	}

	#sendUpdate(): void {
		ws?.send({
			type: 'userUpdate',
			name: this.#name,
			hero: this.#hero,
			choice: JSON.stringify(this.#choice)
		});
	}

	toUserData(): UserData {
		return {
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
	// @todo implement poking
	ws?.send({
		type: 'poke',
		user,
		pokedWith
	});
}

export function reveal() {
	room.revealed = true;
	ws?.send({
		type: 'reveal'
	});
}

function resetChoice() {
	currentUser.choice = null;
	currentUser.edited = false;
}

export function newQuest(questType?: QuestType) {
	room.quest += 1;
	room.questType = questType ?? QuestType.Fibonacci;
	room.revealed = false;
	resetChoice();

	ws?.send({
		type: 'newQuest',
		questType
	});
}
