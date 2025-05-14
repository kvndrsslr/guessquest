<script lang="ts">
	import { currentUser, room, type Choice } from '$lib/app.svelte';

	import { useInactivityTimeout } from '$lib/useInactivityTimeout';
	import { goto } from '$app/navigation';
	import Hero from '$lib/components/Hero.svelte';
	import Card from '$lib/components/Card.svelte';
	import Monster from '$lib/components/Monster.svelte';
	import { MediaQuery } from 'svelte/reactivity';
	import { page } from '$app/state';
	import { flip } from 'svelte/animate';
	import CatGif from '$lib/components/CatGif.svelte';

	const options = [1, 2, 3, 5, 8, 13, 21, 34, '∞', '?'];

	const lg = new MediaQuery('(min-width: 1150px)', true);
	const md = new MediaQuery('(min-width: 860px)', false);
	const sm = new MediaQuery('(min-width: 680px)', false);

	function sortByChoice(a: { choice: Choice | null }, b: { choice: Choice | null }) {
		console.log('Sorting by choice:', a.choice, b.choice, typeof a.choice, typeof b.choice);
		if (a.choice === null) return 1;
		if (b.choice === null) return -1;
		if (typeof a.choice === 'string' && typeof b.choice === 'string') {
			return a.choice.localeCompare(b.choice);
		}
		if (typeof a.choice === 'number' && typeof b.choice === 'number') {
			return a.choice - b.choice;
		}
		if (typeof a.choice === 'string') {
			return 1;
		}
		if (typeof b.choice === 'string') {
			return -1;
		}
		if (Array.isArray(a.choice) && Array.isArray(b.choice)) {
			return a.choice[0] * a.choice[1] - b.choice[0] * b.choice[1];
		}
		return 0; // fallback for unexpected types
	}

	function isEqualChoice(a: Choice | null, b: Choice | null): boolean {
		if (a === b) return true;
		if (a === null || b === null) return false;
		if (typeof a !== typeof b) return false;
		if (Array.isArray(a) && Array.isArray(b)) {
			return a[0] === b[0] && a[1] === b[1];
		}
		return false; // fallback for unexpected types
	}

	let herosPerRow = $derived(2 + +lg.current + +md.current + +sm.current);
	let rows = $derived(Math.ceil((room.otherUsers.length + 1) / herosPerRow));
	let nonNullChoices = $derived(
		// Only include choices from non-spectators
		[...(currentUser.spectator ? [] : [currentUser.toUserData()]), ...room.otherUsers]
			.map((user) => user.choice)
			.filter((choice) => choice !== null)
	);
	let hasConsensus = $derived(
		room.revealed
			? nonNullChoices.length > 0 &&
					nonNullChoices.every((choice) => isEqualChoice(choice, nonNullChoices[0]))
			: false
	);
	let displayedUsers = $derived.by(() => {
		// Filter out current user if they are a spectator
		const users = currentUser.spectator
			? room.otherUsers.map((user, index) => ({
					userId: index + 1,
					...user
				}))
			: [currentUser.toUserData(), ...room.otherUsers].map((user, index) => ({
					userId: index,
					...user
				}));
		return room.revealed ? users.toSorted(sortByChoice) : users;
	});
	$effect(() => {
		if (page.params.roomId!.length > 18) {
			goto(
				`#/${page.params.roomId!.substring(0, 18)}/${page.params?.mode === 'spectator' ? 'spectator' : ''}`
			);
		}
	});
</script>

<svelte:head>
	<title>
		Guess Quest: {page.params.roomId}{page.params.mode === 'spectator' ? ' (Spectator)' : ''}
	</title>
</svelte:head>

<svelte:body use:useInactivityTimeout={{ timeout: 1000 * 60 * 30, onTimeout: () => goto('/') }} />

{#if room.connected}
	<div class="hero-container" style={`--rows: ${rows}`}>
		{#if hasConsensus}
			<CatGif id="cat" choice={nonNullChoices[0]} />
		{/if}
		{#each displayedUsers as { hero, name, choice, userId } (userId)}
			<div animate:flip class="hero-wrapper">
				<Hero
					id={hero}
					name={name ?? 'Unnamed Hero'}
					choice={room.revealed || choice === null ? choice : true}
					currentUser={userId === 0 && !currentUser.spectator ? currentUser : undefined}
				/>
			</div>
		{/each}
	</div>

	<div class="choices-container" class:revealed={room.revealed}>
		<div class="monster">
			<Monster />
		</div>
		{#if !currentUser.spectator}
			<div class="choices">
				{#each options ?? [] as option}
					<Card choice={option} />
				{/each}
			</div>
		{/if}
	</div>
{/if}

<style lang="scss">
	.hero-container {
		width: min(max(66dvw, 1200px), 100dvw);
		display: grid;
		transition: all 0.3s ease-in-out;
		grid-auto-flow: column;
		grid-template-rows: repeat(var(--rows, 1), auto);
		grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
		row-gap: 2em;
	}

	.hero-wrapper {
		opacity: 1;
		transition: opacity 0.5s ease-in-out;
	}

	:global(.hero-container:has(#cat) .hero-wrapper) {
		opacity: 0;
	}

	.choices-container {
		position: fixed;
		bottom: 0;
		width: 100dvw;
		height: 250px;
		display: flex;
		justify-content: center;
		align-items: end;
	}

	.monster {
		position: absolute;
		bottom: 20px;
		left: 0px;
		translate: calc(50dvw - 50%) 0;
		transition: translate 0.8s ease-in-out;
	}

	.revealed .monster {
		translate: 20px 0;
	}

	.choices {
		display: flex;
		align-items: end;
		overflow-x: scroll;
		width: 100%;
		padding: 16px;
		height: 225px;
		gap: 0.6em;
		&:focus {
			outline: none;
		}
		transition: all 0.8s ease-in-out;
	}

	.revealed .choices {
		translate: 0 225px;
		opacity: 0.5;
	}
</style>
