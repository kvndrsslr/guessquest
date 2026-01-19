export const heroImages = Object.fromEntries(
	Object.entries(import.meta.glob('$lib/assets/heroes/*.webp', { eager: true }))
		.map(([path, module]) => {
			const match = path.match(/\/heroes\/(\d+)\.webp$/);
			if (match) {
				return [parseInt(match[1], 10), (module as { default: string }).default] as const;
			}
			return null;
		})
		.filter((a) => a !== null)
);
