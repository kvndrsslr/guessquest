<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import Hero from '#lib/components/Hero.svelte';
	import { CurrentUser } from '#lib/CurrentUser.svelte.js';

	const currentUser = new CurrentUser();

	let sessionName: string = $state('');
	let name: string = $state('');
	let rememberMe: boolean = $state(true);
	let estimationMode: string = $state('points');

	$effect(() => {
		currentUser.setRememberMe(rememberMe);
	});

	function joinSession(e: SubmitEvent) {
		e.preventDefault();
		const asSpectator = (e.submitter as HTMLButtonElement)?.hasAttribute('data-spectator');
		if (sessionName) {
			sessionStorage.setItem('roomType', estimationMode === 'days' ? '1' : '0');
			goto(resolve(`/${sessionName}/${asSpectator ? 'spectator' : ''}`));
		}
	}
</script>

<form class="user-config" onsubmit={joinSession}>
	<!-- 
	// import 'emoji-picker-element';
  {#if browser}
		<emoji-picker></emoji-picker>
	{/if} -->
	<Hero id={currentUser.hero} {name} {currentUser} choice={null} />
	<!-- svelte-ignore a11y_autofocus -->
	<input
		bind:value={sessionName}
		type="text"
		placeholder="Enter room name"
		maxlength="18"
		autofocus
		required
	/>
	<fieldset class="mode">
		<legend>Estimation mode</legend>
		<label>
			<input type="radio" name="estimationMode" value="points" bind:group={estimationMode} />
			Story Points
		</label>
		<label>
			<input type="radio" name="estimationMode" value="days" bind:group={estimationMode} />
			Person Days
		</label>
	</fieldset>
	<div class="buttons">
		<button type="submit">Join</button>
		<button type="submit" data-spectator>Spectate</button>
	</div>
	<label><input name="rememberMe" bind:checked={rememberMe} type="checkbox" />Remember me</label>
</form>

<style lang="scss">
	.user-config {
		display: flex;
		flex-direction: column;
		gap: 1em;
		width: 300px;
		margin: auto;
		padding: 2em;
		border-radius: 8px;
		box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
	}

	input[type='text'] {
		padding: 0.5em;
		border: 1px solid #ccc;
		border-radius: 4px;
	}

	.mode {
		display: flex;
		flex-wrap: wrap;
		gap: 0.75em;
		margin: 0;
		padding: 0.5em 0.75em;
		border: 1px solid #ccc;
		border-radius: 4px;

		legend {
			padding: 0 0.25em;
		}

		label {
			display: flex;
			align-items: center;
			gap: 0.35em;
		}
	}

	.buttons {
		width: 100%;
		display: flex;
		justify-content: stretch;
		gap: 8px;
	}

	button {
		flex: 1 0 0;
		padding: 0.5em;
		border: none;
		border-radius: 4px;
		cursor: pointer;
	}
</style>
