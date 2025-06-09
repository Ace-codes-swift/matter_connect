# Matter Color Demo

This example shows how to control a square's color using a simple HTTP interface.
The program opens an SDL window on your computer and runs a small HTTP server on
port `8080`. Sending a color update from another device (e.g. your phone) will
change the window's background color.

## Building

Ensure [Swift](https://swift.org/download/) and SDL2 are installed on your
system. On Ubuntu you can install SDL2 using:

```bash
sudo apt-get install libsdl2-dev
```

Clone this repository and run:

```bash
swift build -c release
```

## Running

Launch the executable with:

```bash
swift run
```

The program prints the server address. From your phone or another computer on
the network, send a POST request to `/color` containing JSON with `hue`,
`saturation` and `brightness` values in the `0.0`–`1.0` range:

```bash
curl -X POST http://<PC-IP>:8080/color \
  -H 'Content-Type: application/json' \
  -d '{"hue":0.5,"saturation":1.0,"brightness":1.0}'
```

The window background will update to the requested color.
