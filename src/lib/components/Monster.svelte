<script lang="ts">
	import { newQuest, reveal, room } from '$lib/app.svelte';

	let label = $derived(
		room.revealed ? 'Embark on a new Quest' : 'Click the Complexity Monster to Reveal'
	);
</script>

<div class="monster-container">
	<div class="monster" class:revealed={room.revealed}>
		<button
			class="monster-hover-proxy"
			onclick={(ev) => {
				if (room.revealed) {
					newQuest();
				} else {
					reveal();
				}
				ev.currentTarget.blur();
			}}
			aria-label={label}
		></button>
	</div>
	<div class="monster-label">
		{label}<br />
		↓
	</div>
</div>

<style lang="scss">
	@keyframes label-wiggle {
		0% {
			transform: translateY(0px);
			color: var(--text-secondary);
		}
		50% {
			transform: translateY(10px);
			color: var(--text-primary);
		}
		100% {
			transform: translateY(0px);
			color: var(--text-secondary);
		}
	}
	.monster-container {
		position: relative;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
	}
	.monster-label {
		user-select: none;
		position: absolute;
		top: 20px;
		text-align: center;
		transition: opacity 0.2s ease-in-out;
		opacity: 1;

		animation: label-wiggle 2s ease-in-out infinite;
	}
	.monster {
		transition: all 0.4s ease-in-out;
		scale: 0.8;
		transform: translateY(50px);
		background-color: transparent;
		border: none;
		background-image: url('$lib/assets/monster.webp');
		background-repeat: no-repeat;
		background-size: contain;
		background-position: center;
		height: 370px;
		width: 350px;
		position: relative;

		&.revealed {
			background-image: url('$lib/assets/cat-ok.webp');
		}

		.monster-hover-proxy {
			cursor: pointer;
			opacity: 0;
			display: block;
			position: absolute;
			top: 0px;
			right: 18px;
			left: 15px;
			height: 200px;
			transition: all 0.4s ease-in-out;
			&:hover {
				height: 260px;
				right: 0px;
				left: 0px;
			}
		}
		&:has(.monster-hover-proxy:hover, .monster-hover-proxy:focus) {
			+ .monster-label {
				opacity: 0;
			}
			scale: 1;
			transform: translateY(5px);
			filter: drop-shadow(0 0 3px var(--btn-primary)) drop-shadow(0 0 35px var(--btn-primary));
			&.revealed {
				filter: drop-shadow(0 0 3px var(--ready)) drop-shadow(0 0 35px var(--ready));
			}
		}
	}
</style>
