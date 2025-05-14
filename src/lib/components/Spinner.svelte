<script lang="ts">
	import { onMount } from 'svelte';

	let spinSword = $state<boolean>(false);

	onMount(() => {
		let i = 0;
		setInterval(() => {
			if (spinSword) {
				spinSword = false;
			}
			i = (i + 1) % 5;
			if (i === 0 && !spinSword) {
				spinSword = true;
			}
		}, 450);
	});
</script>

<img src={`/sword_${spinSword ? 'spin' : 'still'}.webp`} alt="Sword" />
