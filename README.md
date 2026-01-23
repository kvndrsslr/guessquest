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

#### Using Docker

You can also build and run Guess Quest using Docker. Here's how:

```sh
docker build -t guessquest .
docker run -d -p 48377:48377 guessquest
```

#### Cross-Compiling the Zig Server Binary

In order to cross-compile the Zig server binary for another platform just append the zig compiler parameters to the build command, e.g., for Linux ARM64:

```sh
npm run build:backend -- -Dtarget=aarch64-linux
```

## Running the Server

The Guess Quest server binary can be run with the following command-line options:

```sh
./guessquest-server [OPTIONS]
```

### Command-Line Options

- **`-p <port>`** - Port number to bind to (default: `48377`)
  - Must be a valid port number (1-65535)
- **`-a <address>`** - IP address to bind to (default: `0.0.0.0`)
  - Must be a valid IPv4 or IPv6 address
  - Examples: `127.0.0.1`, `0.0.0.0`, `::1`
- **`-h, --help`** - Display help message and exit

## Hosting

You can host the Guess Quest server on any machine that supports running the compiled binary.
It is generally recommended to run the server behind a reverse proxy like Nginx or Caddy for better security and performance.
An example Nginx configuration is provided in the repository.

## Roadmap

- [ ] Implement timebox estimation mode (in Person Days, not Points)

## Contributing

Contributions are welcome! If you have any ideas or suggestions for new features, please open an issue or submit a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
