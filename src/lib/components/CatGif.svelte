<script lang="ts">
	import type { Choice } from '$lib/app.svelte';
	import { fade } from 'svelte/transition';
	import allCats from 'virtual:cats';

	let { choice, id }: { choice: Choice; id: string } = $props();

	let loaded = $state(false);

	function sfc32(a: number, b: number, c: number, d: number) {
		return function () {
			a |= 0;
			b |= 0;
			c |= 0;
			d |= 0;
			let t = (((a + b) | 0) + d) | 0;
			d = (d + 1) | 0;
			a = b ^ (b >>> 9);
			b = (c + (c << 3)) | 0;
			c = (c << 21) | (c >>> 11);
			c = (c + t) | 0;
			return (t >>> 0) / 4294967296;
		};
	}

	function xmur3a(str: string) {
		for (var k, i = 0, h = 2166136261 >>> 0; i < str.length; i++) {
			k = Math.imul(str.charCodeAt(i), 3432918353);
			k = (k << 15) | (k >>> 17);
			h ^= Math.imul(k, 461845907);
			h = (h << 13) | (h >>> 19);
			h = (Math.imul(h, 5) + 3864292196) | 0;
		}
		h ^= str.length;
		return function () {
			h ^= h >>> 16;
			h = Math.imul(h, 2246822507);
			h ^= h >>> 13;
			h = Math.imul(h, 3266489909);
			h ^= h >>> 16;
			return h >>> 0;
		};
	}

	const src = $derived.by(() => {
		const seed = Math.round(Date.now() / 10000).toString();
		const seedFn = xmur3a(seed + choice);
		const rand = sfc32(seedFn(), seedFn(), seedFn(), seedFn());
		return allCats[Math.floor(rand() * allCats.length)];
	});

	$effect(() => {
		const img = new Image();
		img.onload = () => {
			loaded = true;
		};
		img.src = src;
	});
</script>

{#if loaded}
	<div {id} class="container" transition:fade={{ duration: 500 }}>
		<img {src} alt="Cat GIF" />
		<p>Consensus: {choice}</p>
	</div>
{/if}

<style>
	.container {
		position: fixed;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		z-index: 9999;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1rem;
	}

	img {
		max-width: min(90vw, 500px);
		max-height: min(80vh, 500px);
		border-radius: 8px;
	}

	p {
		font-size: 2rem;
		color: white;
		font-weight: bold;
	}
</style>
