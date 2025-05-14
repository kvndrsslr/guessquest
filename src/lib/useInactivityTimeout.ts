// Svelte action to detect user inactivity and trigger a callback
// Usage: use:useInactivityTimeout={{ timeout: 300000, onTimeout: () => { ... } }}

export interface InactivityOptions {
	timeout: number; // ms
	onTimeout: () => void;
}

export function useInactivityTimeout(node: HTMLElement, options: InactivityOptions) {
	let timer: ReturnType<typeof setTimeout>;
	const events = ['mousemove', 'keydown', 'mousedown', 'touchstart', 'scroll'];

	function resetTimer() {
		clearTimeout(timer);
		timer = setTimeout(() => {
			options.onTimeout();
		}, options.timeout);
	}

	function addListeners() {
		for (const event of events) {
			window.addEventListener(event, resetTimer, true);
		}
	}

	function removeListeners() {
		for (const event of events) {
			window.removeEventListener(event, resetTimer, true);
		}
	}

	addListeners();
	resetTimer();

	return {
		destroy() {
			clearTimeout(timer);
			removeListeners();
		},
		update(newOptions: InactivityOptions) {
			options = newOptions;
			resetTimer();
		}
	};
}
