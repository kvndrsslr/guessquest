<script lang="ts">
	import '@fontsource/medievalsharp';

	let { children } = $props();
	let withKitten = $state(false);

	const preloadImageUrls = [
		...Array(12)
			.keys()
			.map((key) => `/hero${key}.webp`),
		'/card.webp',
		'/monster.webp',
		'/sword_still.webp',
		'/sword_spin.webp',
		'/background-noise.svg'
	];
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

<div class="wrapper">
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
	</header>
	{@render children()}
</div>

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
			padding: 2em 0;
			font-family: 'MedievalSharp', system-ui;
			background-color: var(--bg);

			background-image: url('/background-noise.svg');
			background-blend-mode: soft-light;
			box-shadow: 0 0 22.5vw #000 inset;
			min-height: 100dvh;
			color: var(--text-primary);

			input,
			button,
			textarea {
				font-family: inherit;
			}
		}
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
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 75dvh;
	}
</style>
