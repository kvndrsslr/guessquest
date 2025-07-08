<script lang="ts">
	// import 'emoji-picker-element';
	import { goto } from '$app/navigation';

	let sessionName: string = $state('');
	let name: string = $state('');
	let rememberMe: boolean = $state(false);
	let spectator: boolean = $state(false);

	function joinSession(e: SubmitEvent) {
		e.preventDefault();
		window.sessionStorage.setItem('name', name);
		if (rememberMe) {
			window.localStorage.setItem('name', name);
		} else {
			window.localStorage.removeItem('name');
		}
		if (sessionName) {
			goto(`#/${sessionName}/${spectator ? 'spectator' : ''}`);
		}
	}
</script>

<form onsubmit={joinSession}>
	<!-- {#if browser}
		<emoji-picker></emoji-picker>
	{/if} -->
	<!-- svelte-ignore a11y_autofocus -->
	<input
		bind:value={sessionName}
		type="text"
		placeholder="Enter room name"
		maxlength="18"
		autofocus
		required
	/>
	<input bind:value={name} type="text" placeholder="Enter your name" required />
	<label><input name="rememberMe" bind:checked={rememberMe} type="checkbox" />Remember me</label>
	<label><input name="spectator" bind:checked={spectator} type="checkbox" />Join as spectator</label
	>
	<button type="submit">Join</button>
</form>

<style lang="scss">
	form {
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

	button {
		padding: 0.5em;
		border: none;
		border-radius: 4px;
		cursor: pointer;
	}
</style>
