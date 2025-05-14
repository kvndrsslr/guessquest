import { page } from '$app/state';
import { currentUser, room, type Choice, type UserData } from '$lib/app.svelte';
import { MessageReader, MessageWriter } from '$lib/bit-io';

export enum RoomType {
	StoryPoints = 0,
	PersonDays = 1
}

enum ChoiceType {
	SingleNumber = 0,
	SingleString = 1,
	TwoNumbers = 2,
	None = 3
}

enum MessageType {
	Join = 0,
	Reveal = 1,
	ResetRoom = 2,
	UpdateUserChoice = 3,
	UpdateUserName = 4,
	UpdateUserHero = 5,
	UpdateUserSpectator = 6,
	UserConnected = 7,
	UserDisconnected = 8,
	NotImplemented = 9,
	Reserved1 = 10,
	Sync = 11,
	Reserved2 = 12,
	Poke = 13,
	Ping = 14,
	Pong = 15
}

function writeChoice(writer: MessageWriter, choice: Choice): void {
	if (typeof choice === 'number') {
		writer.writeBits(2, ChoiceType.SingleNumber);
		writer.alignToByte();
		writer.writeBits(8, choice);
	} else if (typeof choice === 'string') {
		writer.writeBits(2, ChoiceType.SingleString);
		writer.alignToByte();
		writer.writeString(choice);
	} else if (Array.isArray(choice) && choice.length === 2) {
		writer.writeBits(2, ChoiceType.TwoNumbers);
		writer.alignToByte();
		writer.writeBits(8, choice[0]);
		writer.writeBits(8, choice[1]);
	} else {
		writer.writeBits(2, ChoiceType.None);
	}
}

function readChoice(reader: MessageReader, choiceType?: ChoiceType): Choice {
	if (choiceType === undefined) {
		choiceType = reader.readBits(2, (n) => n as ChoiceType);
	}
	reader.alignToByte();
	switch (choiceType) {
		case ChoiceType.SingleNumber:
			return reader.readBits(8);
		case ChoiceType.SingleString:
			return reader.readString();
		case ChoiceType.TwoNumbers:
			return reader.readBitsArray(8, 2) as [number, number];
		default:
			return null;
	}
}

export class NetworkClient {
	#ws: WebSocket | null = null;
	#reconnectAttempts = 0;
	#pingTimeout: number | null = null;
	#pongTimeout: number | null = null;
	#shouldReconnect = true;
	#url: string;

	constructor(url: string) {
		this.#url = url;
		this.#connect();
	}

	#heartbeat() {
		if (this.#pingTimeout) clearTimeout(this.#pingTimeout);
		if (this.#pongTimeout) clearTimeout(this.#pongTimeout);

		this.#pingTimeout = setTimeout(() => {
			this.#ws?.send(Uint8Array.from([MessageType.Ping]));
			this.#pongTimeout = setTimeout(() => {
				// No pong received, connection is likely broken
				this.#ws?.close();
			}, 2000);
		}, 20000);
	}

	#connect() {
		if (this.#ws?.readyState === WebSocket.OPEN) {
			console.debug('WebSocket already connected');
			return;
		}

		this.#shouldReconnect = true;
		this.#ws = new WebSocket(this.#url);
		this.#ws.binaryType = 'arraybuffer';

		this.#ws.onopen = () => {
			console.debug('WebSocket connected');
			this.#reconnectAttempts = 0;
			this.#heartbeat();
			this.#sendJoin();
		};

		this.#ws.onmessage = (event) => {
			if (event.data instanceof ArrayBuffer) {
				const reader = new MessageReader(event.data);
				const type = reader.readBits(4);

				// every message counts towards the heartbeat
				this.#heartbeat();

				switch (type) {
					case MessageType.Poke: {
						const poker = reader.readBits(4);
						const poked = reader.readBits(4);
						const pokedWith = reader.readString();
						// TODO implement poking
						console.debug(poker, 'poked', poked, 'with:', pokedWith);
						break;
					}
					case MessageType.UserConnected: {
						const user = {
							id: reader.readBits(4),
							hero: reader.readBits(8),
							spectator: reader.readBits(1, Boolean),
							choice: readChoice(reader),
							name: reader.readString(),
							edited: false
						};

						if (user.spectator) {
							room.spectators.push(user);
						} else {
							room.otherUsers.push(user);
						}

						break;
					}
					case MessageType.UserDisconnected: {
						const userId = reader.readBits(4);
						room.otherUsers = room.otherUsers.filter((u) => u.id !== userId);
						room.spectators = room.spectators?.filter((u) => u.id !== userId);
						break;
					}
					case MessageType.UpdateUserChoice: {
						const userId = reader.readBits(4);
						const choice = readChoice(reader);
						const user = room.otherUsers.find((u) => u.id === userId);
						if (user) {
							user.choice = choice;
							user.edited = !!room.revealed;
						}
						break;
					}
					case MessageType.UpdateUserName: {
						const userId = reader.readBits(4);
						const name = reader.readString();
						const user =
							room.otherUsers.find((u) => u.id === userId) ??
							room.spectators.find((u) => u.id === userId);
						if (user) {
							user.name = name;
						}
						break;
					}
					case MessageType.UpdateUserHero: {
						const userId = reader.readBits(4);
						const hero = reader.readBits(8);
						const user =
							room.otherUsers.find((u) => u.id === userId) ??
							room.spectators.find((u) => u.id === userId);
						if (user) {
							user.hero = hero;
						}
						break;
					}
					case MessageType.UpdateUserSpectator: {
						const userId = reader.readBits(4);
						const spectatorFlag = reader.readBits(1);
						if (spectatorFlag) {
							const userIndex = room.otherUsers.findIndex((u) => u.id === userId);
							if (userIndex !== -1) {
								const [spectatorUser] = room.otherUsers.splice(userIndex, 1);
								spectatorUser.spectator = true;
								room.spectators.push(spectatorUser);
							}
						} else {
							const spectatorIndex = room.spectators.findIndex((u) => u.id === userId);
							if (spectatorIndex !== -1) {
								const [returningUser] = room.spectators.splice(spectatorIndex, 1);
								returningUser.spectator = false;
								room.otherUsers.push(returningUser);
							}
						}
						break;
					}
					case MessageType.Reveal: {
						room.revealed = true;
						break;
					}
					case MessageType.ResetRoom: {
						const roomType = reader.readBits(1, (n) => n as RoomType);
						room.quest += 1;
						room.roomType = roomType;
						room.revealed = false;
						currentUser.choice = null;
						currentUser.edited = false;
						room.otherUsers.forEach((u) => {
							u.choice = null;
							u.edited = false;
						});
						break;
					}
					case MessageType.Sync: {
						currentUser.id = reader.readBits(4);
						room.roomType = reader.readBits(1, (n) => n as RoomType);
						room.revealed = reader.readBits(1, Boolean);
						const userCount = reader.readBits(6);
						room.quest = reader.readBits(8);
						const userIds = reader.readBitsArray(4, userCount);
						const heroes = reader.readBitsArray(8, userCount);
						const spectatorFlags = reader.readBitsArray(1, userCount, Boolean);
						const editedFlags = reader.readBitsArray(1, userCount, Boolean);
						const choiceTypes = reader.readBitsArray(2, userCount, (n) => n as ChoiceType);
						const choices: Choice[] = [];
						for (let i = 0; i < userCount; i++) {
							const c = readChoice(reader, choiceTypes[i]);
							choices.push(c);
						}
						const names = reader.readStringArray(userCount);
						const otherUsers: UserData[] = [];
						for (let i = 0; i < userCount; i++) {
							otherUsers.push({
								id: userIds[i],
								hero: heroes[i],
								spectator: spectatorFlags[i],
								choice: choices[i],
								name: names[i],
								edited: editedFlags[i]
							});
						}
						room.otherUsers = otherUsers.filter((u) => !u.spectator);
						room.spectators = room.otherUsers.filter((u) => u.spectator);
						room.connected = true;
						break;
					}
					default:
						break;
				}
			}
		};

		this.#ws.onclose = () => {
			console.debug('WebSocket closed');
			room.connected = false;
			this.#reconnect();
		};

		this.#ws.onerror = (error) => {
			console.error('WebSocket error:', error);
			room.connected = false;
			this.#ws?.close();
		};
	}

	#reconnect() {
		if (this.#shouldReconnect) {
			this.#reconnectAttempts++;
			const backoff = Math.min(Math.log10(this.#reconnectAttempts) * 1200, 5000);
			const jitter = Math.random() * 1000;
			const delay = backoff + jitter;
			console.debug(`Reconnecting in ${delay}ms`);
			setTimeout(() => this.#connect(), delay);
		}
	}

	#send(cb: (writer: MessageWriter) => void): void {
		if (this.#ws?.readyState === WebSocket.OPEN) {
			const writer = new MessageWriter();
			cb(writer);
			const data = writer.finalize();
			this.#ws.send(data);
		} else {
			console.error('WebSocket not connected', this.#ws?.readyState);
			if (this.#ws?.readyState === WebSocket.CLOSING) {
				room.connected = false;
				this.#reconnect();
			}
		}
	}

	#sendJoin() {
		this.#send((writer) => {
			writer.writeBits(4, MessageType.Join);
			writer.writeBits(8, currentUser.hero);
			writer.writeBits(1, room.roomType);
			writer.writeBits(1, +currentUser.spectator);
			writeChoice(writer, currentUser.choice);
			writer.writeString(page.params.roomId!.substring(0, 18));
			writer.writeString(currentUser.name);
		});
	}

	sendReveal() {
		this.#send((writer) => {
			writer.writeBits(4, MessageType.Reveal);
		});
	}

	sendResetRoom({ roomType }: { roomType: RoomType }) {
		this.#send((writer) => {
			writer.writeBits(4, MessageType.ResetRoom);
			writer.writeBits(1, roomType);
		});
	}

	sendUpdateUserChoice({ choice }: { choice: Choice }) {
		this.#send((writer) => {
			writer.writeBits(4, MessageType.UpdateUserChoice);
			writeChoice(writer, choice);
		});
	}

	sendUpdateUserName({ name }: { name: string }) {
		this.#send((writer) => {
			writer.writeBits(4, MessageType.UpdateUserName);
			writer.writeString(name);
		});
	}

	sendUpdateUserHero({ hero }: { hero: number }) {
		this.#send((writer) => {
			writer.writeBits(4, MessageType.UpdateUserHero);
			writer.writeBits(8, hero);
		});
	}

	sendUpdateUserSpectator({ spectator }: { spectator: boolean }) {
		this.#send((writer) => {
			writer.writeBits(4, MessageType.UpdateUserSpectator);
			writer.writeBits(1, spectator);
		});
	}

	sendPoke({ poked, pokedWith }: { poked: number; pokedWith: string }) {
		this.#send((writer) => {
			writer.writeBits(4, MessageType.Poke);
			writer.writeBits(4, poked);
			writer.writeString(pokedWith);
		});
	}

	close() {
		this.#shouldReconnect = false;
		if (this.#pingTimeout) clearTimeout(this.#pingTimeout);
		if (this.#pongTimeout) clearTimeout(this.#pongTimeout);
		this.#ws?.close();
	}
}
