<script lang="ts">
	import type { Choice } from '$lib/app.svelte';
	import type { CurrentUser } from '$lib/CurrentUser.svelte';
	import { heroImages } from '$lib/heroImages';

	type HeroProps = {
		id: number;
		name: string;
		choice: Choice | null | true;
		currentUser?: CurrentUser;
	};

	const { id, name, choice, currentUser }: HeroProps = $props();

	let inputElement: HTMLInputElement | null = $state(null);
	let mirrorElement: HTMLSpanElement | null = $state(null);

	let inputWidth = $state('50px'); // Initialize with min-width

	// Use $effect to reactively update width when value or placeholder changes
	$effect(() => {
		if (inputElement && mirrorElement && currentUser) {
			// eslint-disable-next-line svelte/no-dom-manipulating -- needed for measuring text width
			mirrorElement.textContent =
				inputElement.placeholder.length >= currentUser.name.length
					? inputElement.placeholder
					: currentUser.name;
			// Add a small buffer to the calculated width
			inputWidth = `${mirrorElement.scrollWidth + 8}px`;
		}
	});
</script>

<!-- svelte-ignore a11y_click_events_have_key_events -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
	class="hero"
	style={`background-image: url('${heroImages[id]}')`}
	class:ready={choice}
	onclick={(ev) => {
		if (currentUser && ev.target === ev.currentTarget) {
			currentUser.cycleHero();
		}
	}}
	oncontextmenu={(ev) => {
		ev.preventDefault();
		if (currentUser) {
			currentUser.cycleHero(-1);
		}
	}}
>
	{#if currentUser}
		<input
			bind:this={inputElement}
			type="text"
			bind:value={currentUser.name}
			onkeydown={(ev) => {
				if (ev.key === 'Enter') {
					ev.currentTarget.blur();
				}
			}}
			maxlength={18}
			placeholder="Name"
			style={`width: ${inputWidth};`}
		/>
		<div bind:this={mirrorElement} class="name mirror" aria-hidden="true"></div>
	{:else}
		<div class="name">
			{name}
		</div>
	{/if}

	{#if choice !== null && choice !== true}
		<div class="choice" class:edited={currentUser?.edited}>
			{choice}
		</div>
	{/if}
</div>

<style lang="scss">
	.hero {
		user-select: none;
		background-repeat: no-repeat;
		background-size: auto 150px;
		background-position: bottom;
		width: 180px;
		margin: 0 auto;
		height: 185px;
		color: var(--text-primary);
		font-size: 1.4rem;
		text-align: center;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: space-between;
		transition: filter 0.25s ease-in-out;
		&.ready {
			filter: drop-shadow(0 0 3px var(--ready)) drop-shadow(0 0 48px var(--ready));
		}
	}
	.name {
		text-overflow: ellipsis;
		white-space: nowrap;
		height: 1em;
		overflow: hidden;
		&.mirror {
			visibility: hidden;
			position: absolute;
			top: 0;
			left: 0;
		}
	}
	.choice {
		width: 33px;
		height: 33px;
		line-height: 35px;
		border: 3px solid var(--highlight);
		border-radius: 100%;
		padding: 5px;
		background-color: var(--btn-secondary);
		text-align: center;
		color: var(--text-primary);
		&.edited {
			background-color: var(--edited);
		}
	}

	input {
		height: 1em;
		transform: translateY(-0.2em);
		background-color: transparent;
		color: var(--text-primary);
		font-size: 1.4rem;
		text-align: center;
		border: 2px solid transparent;
		border-radius: 5px;
		padding: 0.2em;
		display: block;
		// field-sizing: content;
		outline: none;
		&:focus {
			border: 2px solid var(--highlight);
			background-color: var(--bg-alt);
		}
	}
</style>
