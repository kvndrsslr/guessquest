<script lang="ts">
	import { currentUser, room } from '#lib/app.svelte.js';
	import { decodeEstimate, encodeEstimate } from '#lib/estimation.js';

	let people = $state<number | ''>('');
	let days = $state<number | ''>('');
	let ready = $derived(Array.isArray(currentUser.choice));

	// Quest the draft belongs to: a new quest clears the fields, while un-readying
	// locally keeps the previous estimate around to tweak.
	let draftQuest: number | null = null;

	$effect(() => {
		const choice = currentUser.choice;
		if (Array.isArray(choice)) {
			const estimate = decodeEstimate(choice);
			people = estimate.people;
			days = estimate.days;
			draftQuest = room.quest;
		} else if (room.quest !== draftQuest) {
			people = '';
			days = '';
			draftQuest = room.quest;
		}
	});

	function vote(e: SubmitEvent) {
		e.preventDefault();
		if (ready) {
			currentUser.choice = null;
			return;
		}
		if (people === '' || days === '') {
			return;
		}
		currentUser.choice = encodeEstimate(people, days);
	}
</script>

<form class="estimate" onsubmit={vote}>
	<label>
		People
		<input
			bind:value={people}
			type="number"
			min="1"
			step="1"
			placeholder="1"
			required
			disabled={ready}
		/>
	</label>
	<label>
		Days each
		<input
			bind:value={days}
			type="number"
			min="0.25"
			step="0.25"
			placeholder="0.25"
			required
			disabled={ready}
		/>
	</label>
	<button type="submit" class:active={ready} aria-pressed={ready}>Ready</button>
</form>

<style lang="scss">
	.estimate {
		margin: 0 auto 12px;
		display: flex;
		flex-wrap: wrap;
		justify-content: center;
		align-items: flex-end;
		gap: 1em;
		max-width: 100%;
		color: var(--text-primary);

		label {
			display: flex;
			flex-direction: column;
			gap: 4px;
			font-size: 0.9rem;
		}

		input {
			box-sizing: border-box;
			width: 6.5em;
			padding: 8px 10px;
			border: 2px solid var(--highlight);
			border-radius: 8px;
			background-color: var(--bg-alt);
			color: var(--text-primary);
			font-size: 1.2rem;
			text-align: center;

			&:disabled {
				opacity: 0.6;
				cursor: not-allowed;
			}
		}

		button {
			padding: 10px 20px;
			border: none;
			border-radius: 8px;
			background-color: var(--btn-secondary);
			color: var(--text-primary);
			font-size: 1.2rem;
			cursor: pointer;
			transition:
				background-color 0.2s ease-in-out,
				box-shadow 0.2s ease-in-out;

			&.active {
				background-color: var(--ready);
				box-shadow:
					0 0 3px var(--ready),
					0 0 24px var(--ready);
			}
		}
	}
</style>
