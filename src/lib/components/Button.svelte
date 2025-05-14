<script lang="ts">
	import { Button, type ButtonRootProps } from 'bits-ui';

	const { title, ...props }: ButtonRootProps & { title: string } = $props();
</script>

<Button.Root class="gq-button" {...props}>
	{title}
</Button.Root>

<style>
	:global(.gq-button) {
		background-color: var(--button-bg);
	}
</style>
