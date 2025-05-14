# Guess Quest

![CI](https://github.com/kvndrsslr/guessquest/actions/workflows/ci.yml/badge.svg?branch=main)
![GitHub](https://img.shields.io/github/license/kvndrsslr/guessquest?style=flat&logo=github)

Guess Quest is a simple open-source planning poker game that allows teams to estimate the effort required to complete a task.
It's framed as a fantasy game where heroes (team members) must guess the difficulty of quests (tasks) to slay the complexity monster and rescue the cat princess.

Implemented in Svelte-kit with a custom WebSocket server for real-time collaboration.

## Roadmap

- [ ] Implement observer mode (including button to quickly open observer tab)
- [ ] Implement post-reveal display including vote distribution
- [ ] Implement post-reveal mutation of votes
- [ ] Implement Status text in top of page (e.g. "Waiting for all heroes to vote")
- [ ] Implement Countdown timer for voting phase
- [ ] Prompt for user name on first open
- [ ] Implement Timebox estimation mode (in Person Days, not Points)
- [ ] Implement the WebSocket server in Zig + use adapter-static for SvelteKit
- [ ] Add Mobile support ?

## Contributing

Contributions are welcome! If you have any ideas or suggestions for new features, please open an issue or submit a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
