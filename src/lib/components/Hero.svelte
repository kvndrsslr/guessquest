<script lang="ts">
	import { currentUser, type Choice } from '$lib/app.svelte';

	type HeroProps = {
		id: number;
		name: string;
		choice: Choice | null | true;
		isCurrentUser?: boolean;
	};

	const props: HeroProps = $props();

	let inputElement: HTMLInputElement | null = $state(null);
	let mirrorElement: HTMLSpanElement | null = $state(null);

	let inputWidth = $state('50px'); // Initialize with min-width

	// Use $effect to reactively update width when value or placeholder changes
	$effect(() => {
		if (inputElement && mirrorElement) {
			mirrorElement.textContent =
				inputElement.placeholder.length >= currentUser.name.length
					? inputElement.placeholder
					: currentUser.name;
			// Add a small buffer to the calculated width
			inputWidth = `${mirrorElement.scrollWidth + 4}px`;
		}
	});
</script>

<div
	class="hero"
	style={`background-image: url('/hero${props.id}.webp')`}
	class:ready={props.choice}
	onclick={(ev) => {
		if (props.isCurrentUser && ev.target === ev.currentTarget) {
			currentUser.cycleHero();
		}
	}}
>
	{#if props.isCurrentUser}
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
		<div bind:this={mirrorElement} class="name mirror" aria-hidden></div>
	{:else}
		<div class="name">
			{props.name}
		</div>
	{/if}

	{#if props.choice !== null && props.choice !== true}
		<div class="choice" class:edited={currentUser.edited}>
			{props.choice}
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
