<script lang="ts">
	import { Tooltip } from 'bits-ui';
	import { type Snippet } from 'svelte';
	import { fly } from 'svelte/transition';

	type Props = Tooltip.RootProps & {
		href?: string;
		onClick?: () => void;
		trigger: Snippet;
		triggerProps?: Tooltip.TriggerProps;
	};

	let {
		open = $bindable(false),
		children,
		href,
		onClick,
		trigger,
		triggerProps = {},
		...restProps
	}: Props = $props();
</script>

<Tooltip.Root bind:open {...restProps} delayDuration={0}>
	<Tooltip.Trigger {...triggerProps} class="gq-tooltip-trigger">
		{#snippet child({ props })}
			<button {...props} onclick={() => (href ? window.open(href, '_blank') : onClick?.())}>
				{@render trigger()}
			</button>
		{/snippet}
	</Tooltip.Trigger>
	<Tooltip.Portal>
		<Tooltip.Content forceMount class="gq-tooltip-content">
			{#snippet child({ wrapperProps, props, open })}
				{#if open}
					<div {...wrapperProps}>
						<div {...props} transition:fly>
							{@render children?.()}
						</div>
					</div>
				{/if}
			{/snippet}
		</Tooltip.Content>
	</Tooltip.Portal>
</Tooltip.Root>

<style>
	:global(.gq-tooltip-trigger) {
		background: transparent;
		border: none;
		padding: 0;
		margin: 0;
		cursor: pointer;
		color: var(--text-secondary);
		transition: color 0.4s ease-in-out;
		&:hover {
			color: var(--text-primary);
		}
	}
	:global(.gq-tooltip-content) {
		margin: 8px;
		background-color: var(--bg-alt);
		color: var(--text-primary);
		border: 2px solid var(--border);
		border-radius: 8px;
		padding: 8px 12px;
		font-size: 0.9em;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
		max-width: 200px;
		text-align: center;
	}
</style>
