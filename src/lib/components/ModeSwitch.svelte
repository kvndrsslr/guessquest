<script lang="ts">
	import { newQuest, room } from '#lib/app.svelte.js';
	import { RoomType } from '#lib/network.js';

	const modes = [
		{ type: RoomType.StoryPoints, label: 'Story Points' },
		{ type: RoomType.PersonDays, label: 'Person Days' }
	];

	function select(type: RoomType) {
		if (type === room.roomType) {
			return;
		}
		newQuest(type);
	}
</script>

<div class="mode-switch" role="group" aria-label="Estimation mode">
	{#each modes as mode (mode.type)}
		<button
			type="button"
			class:active={room.roomType === mode.type}
			aria-pressed={room.roomType === mode.type}
			onclick={() => select(mode.type)}
		>
			{mode.label}
		</button>
	{/each}
</div>

<style lang="scss">
	.mode-switch {
		position: fixed;
		top: 12px;
		left: 50%;
		transform: translateX(-50%);
		z-index: 10;
		display: flex;
		gap: 4px;
		padding: 4px;
		border: 2px solid var(--highlight);
		border-radius: 100px;
		background-color: var(--btn-secondary);
	}

	button {
		border: none;
		border-radius: 100px;
		padding: 6px 14px;
		background-color: transparent;
		color: var(--text-primary);
		font: inherit;
		cursor: pointer;
		transition: background-color 0.2s ease-in-out;

		&.active {
			background-color: var(--ready);
		}
	}
</style>
