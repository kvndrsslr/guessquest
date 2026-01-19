<script lang="ts">
	import { currentUser, type Choice } from '$lib/app.svelte';

	type CardProps = {
		choice: Choice;
	};

	const props: CardProps = $props();
</script>

<button
	type="button"
	class="card"
	class:active={currentUser.choice === props.choice}
	onclick={() => (currentUser.choice = props.choice)}
>
	{props.choice}
</button>

<style lang="scss">
	.card {
		&:first-child {
			margin-left: auto;
		}

		&:last-child {
			margin-right: auto;
		}

		pointer-events: all;
		user-select: none;
		background-image: url('$lib/assets/card.webp');
		background-repeat: no-repeat;
		background-size: contain;
		height: 136px;
		width: 96px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex: 0 0 auto;
		font-size: 2.4em;
		color: #571313;
		text-shadow:
			0 0 2px #57131388,
			0 0 4px #801c1c88;
		background-color: transparent;
		border-radius: 12px;
		border: 0px solid transparent;
		margin: 0;
		padding: 0;
		transition: all 0.25s ease-in-out;
		transform: scale(0.85);
		cursor: pointer;
		&:hover,
		&:focus {
			transform: scale(0.95) translateY(-6px);
			filter: drop-shadow(0 0 3px var(--highlight)) drop-shadow(0 0 12px var(--highlight));
			outline: none;
		}
		&.active {
			transform: scale(1.1) translateY(-12px);
			filter: drop-shadow(0 0 3px var(--ready)) drop-shadow(0 0 28px var(--ready));
		}
	}
</style>
