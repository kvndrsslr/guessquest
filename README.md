# Guess Quest

![CI](https://github.com/kvndrsslr/guessquest/actions/workflows/ci.yml/badge.svg?branch=main)
![GitHub](https://img.shields.io/github/license/kvndrsslr/guessquest?style=flat&logo=github)

Guess Quest is a simple open-source planning poker game that allows teams to estimate the effort required to complete a task.
It's framed as a fantasy game where heroes (team members) must guess the difficulty of quests (tasks) to slay the complexity monster and rescue the cat princess.

Frontend implemented in Svelte-kit, Static HTTP & Websocket server implemented in Zig, custom binary protocol for very small bandwidth usage.
One small statically linked binary <10MB, needs about ~3MB RAM to run, can handle hundreds of concurrent connections on a small VPS.

## Installation

### Download Precompiled Binary

You can download the latest precompiled binary for common platforms from the [releases](https://github.com/kvndrsslr/guessquest/releases) page.

### Build from Source

To build Guess Quest from source, you'll need to have NodeJS (`>=24`) & Zig (`==0.15.2`) installed on your machine.
Then follow these steps:

```sh
git clone https://github.com/kvndrsslr/guessquest.git
cd guessquest
npm ci
npm run build
```

In order to cross-compile the Zig server binary for another platform just append the zig compiler parameters to the build command, e.g., for Linux ARM64:

```sh
npm run build:backend -- -Dtarget=aarch64-linux
```

## Roadmap

- [ ] Implement timebox estimation mode (in Person Days, not Points)

## Contributing

Contributions are welcome! If you have any ideas or suggestions for new features, please open an issue or submit a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
