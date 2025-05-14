import type { Choice, RoomData, UserData } from '$lib/app.svelte';
import { page } from '$app/state';
import type { NetworkClient } from '$lib/network';

export class CurrentUser {
	id: number = $state(0);
	spectator: boolean = $derived(page.params.mode === 'spectator');
	#name: string = $state('Unknown Hero');
	#hero: number = $state(0);
	#choice: Choice | null = $state(null);
	edited = $state(false);
	#net?: NetworkClient;
	#room?: RoomData;

	constructor(net?: NetworkClient, room?: RoomData) {
		this.#net = net;
		this.#room = room;

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
		this.#net?.sendUpdateUserName({ name: this.#name });
	}

	get name(): string {
		return this.#name;
	}

	cycleHero(dir: 1 | -1 = 1): void {
		console.log('Cycling hero', this.#hero);
		this.hero = (this.#hero + dir + 32) % 32;
		console.log('New hero', this.#hero);
	}

	setRememberMe(remember: boolean): void {
		if (remember) {
			window.localStorage.setItem('name', this.#name);
			window.localStorage.setItem('hero', this.#hero.toString());
		} else {
			window.localStorage.removeItem('name');
			window.localStorage.removeItem('hero');
		}
	}

	set hero(hero: number) {
		this.#hero = hero;
		if (window.localStorage.getItem('name')) {
			window.localStorage.setItem('hero', hero.toString());
		}
		window.sessionStorage.setItem('hero', hero.toString());
		this.#net?.sendUpdateUserHero({ hero: this.#hero });
	}

	get hero(): number {
		return this.#hero;
	}

	set choice(choice: Choice) {
		if (!this.#room) {
			return;
		}
		if (!this.#room.revealed && this.#choice === choice) {
			this.#choice = null;
		} else if (this.#room.revealed && this.#choice === choice) {
			return;
		} else {
			this.edited = this.#room.revealed;
			this.#choice = choice;
		}
		this.#net?.sendUpdateUserChoice({ choice: this.#choice });
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
