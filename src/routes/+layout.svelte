<script lang="ts">
	import '@fontsource/medievalsharp';
	import { Tooltip } from 'bits-ui';
	import { GithubIcon, CopyIcon, HatGlassesIcon, CheckIcon } from '@lucide/svelte';
	import ActionTooltip from '$lib/components/ActionTooltip.svelte';
	import { fade } from 'svelte/transition';
	import { beforeNavigate } from '$app/navigation';

	let { children } = $props();
	let withKitten = $state(false);
	let copySuccess = $state(false);
	let isQuest = $state(window.location.hash.length > 1);

	beforeNavigate((nav) => {
		isQuest = !!nav.to?.params?.roomId;
	});

	const loadOnMountImageUrls = [
		...Array(32)
			.keys()
			.map((key) => `/heroes/${key}.webp`),
		'/logo-small-kitten.webp',
		'/cat-happy.webp',
		'/cat-ok.webp',
		'/monster.webp',
		'/card.webp'
	];

	const preloadImageUrls = ['/heroes/0.webp', '/logo-small.webp', '/background-noise.svg'];
	// preload images on load
	$effect(() => {
		loadOnMountImageUrls.forEach((url) => {
			const img = new Image();
			img.src = url;
		});
	});
</script>

<svelte:head>
	<title>Guess Quest</title>
	<meta name="description" content="A simple open-source planning poker game for Agile teams." />
	<meta name="viewport" content="width=device-width, initial-scale=1.0" />
	{#each preloadImageUrls as image}
		<link rel="preload" as="image" href={image} />
	{/each}
	<!-- Favicon for modern browsers -->
	<link rel="icon" type="image/webp" href="/favicon.webp" />
	<!-- Fallback PNG favicon -->
	<link rel="icon" type="image/png" href="/favicon.png" />
	<!-- Apple Touch Icon -->
	<link rel="apple-touch-icon" sizes="180x180" href="/favicon-180.png" />
	<!-- ICO format for legacy browsers -->
	<link rel="icon" type="image/x-icon" href="/favicon.ico" />
</svelte:head>

<Tooltip.Provider>
	<header>
		<!-- svelte-ignore a11y_click_events_have_key_events -->
		<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
		<img
			id="logo"
			src={`/logo-small${withKitten ? '-kitten' : ''}.webp`}
			alt="GuessQuest Logo"
			onclick={() => {
				withKitten = !withKitten;
			}}
		/>
		<nav class="links">
			{#if isQuest}
				<ActionTooltip
					onClick={() => {
						navigator.clipboard.writeText(window.location.href);
						copySuccess = true;
						setTimeout(() => {
							copySuccess = false;
						}, 2000);
					}}
				>
					{#snippet trigger()}
						<span class="icon-with-feedback">
							{#if copySuccess}
								<span transition:fade>
									<CheckIcon color="var(--ready)" />
								</span>
							{:else}
								<span transition:fade>
									<CopyIcon />
								</span>
							{/if}
						</span>
					{/snippet}
					Copy Quest URL
				</ActionTooltip>
				<ActionTooltip
					onClick={() => {
						const spectatorUrl = new URL(window.location.href);
						spectatorUrl.hash += spectatorUrl.hash.at(-1) === '/' ? 'spectator' : '/spectator';
						window.open(spectatorUrl.toString(), '_blank');
					}}
				>
					{#snippet trigger()}
						<HatGlassesIcon />
					{/snippet}
					Open Spectator Tab<br />(Great for Screen Shares)
				</ActionTooltip>
			{/if}
			<ActionTooltip href="https://github.com/kvndrsslr/guessquest">
				{#snippet trigger()}
					<GithubIcon />
				{/snippet}
				View on GitHub
			</ActionTooltip>
		</nav>
	</header>
	<div class="wrapper">
		{@render children()}
	</div>
</Tooltip.Provider>

<style lang="scss">
	:global {
		:root {
			/* Light Mode (Default) */
			--bg: #e3cfa0; /* Parchment Beige */
			--bg-alt: #c8af7c; /* Aged Paper */
			--border: #5c3b1e; /* Deep Umber */
			--accent: #b18f5b; /* Bronze */
			--text-primary: #2d2b28; /* Charcoal Ink */
			--text-secondary: #4f4f4f; /* Iron Gray */
			--btn-primary: #801c1c; /* Crimson Red */
			--btn-primary-hover: #a42b2b;
			--btn-secondary: #4f8bb3; /* Steel Blue */
			--highlight: #c4a23f; /* Old Gold */
			--edited: #a2762b; /* Highlight Gold */
			--ready: #2b791b; /* green */
			--shadow: rgba(0, 0, 0, 0.66);
			@media (prefers-color-scheme: dark) {
				/* Dark Mode */
				--bg: #1f1b16; /* Deep Parchment Charcoal */
				--bg-alt: #2b251d; /* Ashen Umber */
				--border: #625237; /* Mossy Bronze */
				--accent: #4a3d29; /* Iron Oak */
				--text-primary: #d5c7a2; /* Worn Parchment */
				--text-secondary: #8e8c85; /* Steel Gray */
				--btn-primary: #9e2b2b; /* Crimson Banner */
				--btn-primary-hover: #b03636;
				--btn-secondary: #3f6264; /* Enchanted Teal */
				--highlight: #bfa24d; /* Crown Gold */
				--edited: #a2762b; /* Highlight Gold */
				--ready: #4f8524; /* green */
				--shadow: rgba(0, 0, 0, 1);
			}

			cursor: url('/cursor.webp'), auto;

			/* Style the scrollbars */
			::-webkit-scrollbar {
				width: 12px;
				height: 12px;
			}
			::-webkit-scrollbar-thumb {
				background-color: var(--bg-alt);
				border-radius: 6px;
			}
			::-webkit-scrollbar-track {
				background-color: var(--bg);
			}
			::-webkit-scrollbar-corner {
				background-color: var(--bg);
			}
			::-webkit-scrollbar-button {
				background-color: var(--bg);
			}
			::-webkit-scrollbar-thumb:hover {
				background-color: var(--bg-alt);
			}
			::-webkit-scrollbar-thumb:active {
				background-color: var(--bg-alt);
			}
		}
		body {
			box-sizing: border-box;
			margin: 0;
			padding: 0;
			font-family: 'MedievalSharp', system-ui;
			background-color: var(--bg);

			background-image: url('/background-noise.svg');
			background-blend-mode: soft-light;
			box-shadow: 0 0 22.5vw var(--shadow) inset;
			min-height: 100dvh;
			color: var(--text-primary);

			input,
			button,
			textarea {
				font-family: inherit;
			}
		}
	}

	header nav {
		position: fixed;
		top: 24px;
		right: 32px;
		display: flex;
		gap: 16px;
		align-items: center;
		justify-content: space-between;
	}

	#logo {
		position: fixed;
		top: 16px;
		left: 32px;
		height: 80px;
		width: 150px;
		cursor: pointer;
	}

	.wrapper {
		padding-top: 2.5dvh;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 75dvh;
	}
	// Grid with one cell to overlay both icons and fade between them
	.icon-with-feedback {
		display: grid;
		grid-template-columns: 1fr;
		grid-template-rows: 1fr;
		align-items: center;
		justify-items: center;
		& > * {
			grid-column: 1 / 2;
			grid-row: 1 / 2;
		}
	}
</style>
