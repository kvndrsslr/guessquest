<script lang="ts">
	let { value, placeholder } = $props<{ value: string; placeholder: string }>();

	let inputElement: HTMLInputElement;
	let mirrorElement: HTMLSpanElement;

	let inputWidth = $state('50px'); // Initialize with min-width

	const calculateWidth = () => {
		if (inputElement && mirrorElement) {
			// eslint-disable-next-line svelte/no-dom-manipulating -- needed for measuring text width
			mirrorElement.textContent = value || placeholder || ' ';
			// Add a small buffer to the calculated width
			inputWidth = `${mirrorElement.scrollWidth}px`;
		}
	};

	// Use $effect to reactively update width when value or placeholder changes
	$effect(() => {
		calculateWidth();
	});
</script>

<input
	bind:this={inputElement}
	bind:value
	{placeholder}
	type="text"
	class="p-2 border rounded"
	style="width: {inputWidth};"
/>
<span
	bind:this={mirrorElement}
	aria-hidden="true"
	style="
      position: absolute;
      top: 0;
      left: 0;
      white-space: pre;
      visibility: hidden;
      pointer-events: none;
      /* Inherit relevant styles from the input for accurate measurement */
      font-family: inherit;
      font-size: inherit;
      font-weight: inherit;
      letter-spacing: inherit;
      /* Explicitly match padding, border, border-radius, and box-sizing from input's classes/styles */
      padding: 0.5rem;
      border-width: 1px;
      border-style: solid;
      border-radius: 0.25rem;
      box-sizing: border-box;
    "
></span>

<style>
	/* Ensure the input and mirror have the same font styles */
	input {
		font-family: inherit;
		font-size: inherit;
		font-weight: inherit;
		letter-spacing: inherit;
		text-align: center;
		min-width: 50px;
		box-sizing: border-box;
	}
</style>
