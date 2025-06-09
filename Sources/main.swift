import SDL
import CSDL2
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOConcurrencyHelpers
import Foundation

struct ColorRequest: Codable {
    let hue: Double
    let saturation: Double
    let brightness: Double
}

func hsbToRGB(h: Double, s: Double, b: Double) -> (UInt8, UInt8, UInt8) {
    let c = b * s
    let x = c * (1 - abs((h * 6).truncatingRemainder(dividingBy: 2) - 1))
    let m = b - c
    let hPrime = Int((h * 6)) % 6
    let (r1, g1, b1): (Double, Double, Double)
    switch hPrime {
    case 0: (r1, g1, b1) = (c, x, 0)
    case 1: (r1, g1, b1) = (x, c, 0)
    case 2: (r1, g1, b1) = (0, c, x)
    case 3: (r1, g1, b1) = (0, x, c)
    case 4: (r1, g1, b1) = (x, 0, c)
    default: (r1, g1, b1) = (c, 0, x)
    }
    let r = UInt8(max(0, min(255, Int((r1 + m) * 255))))
    let g = UInt8(max(0, min(255, Int((g1 + m) * 255))))
    let b = UInt8(max(0, min(255, Int((b1 + m) * 255))))
    return (r, g, b)
}

final class ColorHTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private var buffer: ByteBuffer?
    private var expectingColor = false
    private let onColor: (ColorRequest) -> Void

    init(onColor: @escaping (ColorRequest) -> Void) {
        self.onColor = onColor
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapInboundIn(data)
        switch part {
        case .head(let head):
            if head.uri == "/color" && head.method == .POST {
                expectingColor = true
                buffer = context.channel.allocator.buffer(capacity: 0)
            } else {
                respond(status: .notFound, context: context)
            }
        case .body(var buf):
            if expectingColor {
                buffer?.writeBuffer(&buf)
            }
        case .end:
            if expectingColor, var buf = buffer,
               let bytes = buf.readBytes(length: buf.readableBytes) {
                let data = Data(bytes)
                if let color = try? JSONDecoder().decode(ColorRequest.self, from: data) {
                    onColor(color)
                    respond(status: .ok, body: "OK", context: context)
                } else {
                    respond(status: .badRequest, context: context)
                }
            } else if expectingColor {
                respond(status: .badRequest, context: context)
            }
            expectingColor = false
            buffer = nil
        }
    }

    private func respond(status: HTTPResponseStatus, body: String = "", context: ChannelHandlerContext) {
        var headers = HTTPHeaders()
        headers.add(name: "Content-Length", value: "\(body.utf8.count)")
        let head = HTTPResponseHead(version: .http1_1, status: status, headers: headers)
        context.write(wrapOutboundOut(.head(head)), promise: nil)
        if !body.isEmpty {
            var buf = context.channel.allocator.buffer(capacity: body.utf8.count)
            buf.writeString(body)
            context.write(wrapOutboundOut(.body(.byteBuffer(buf))), promise: nil)
        }
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }
}

@main
struct MatterColorApp {
    static func main() throws {
        try SDL.initialize(subSystems: [.video])
        defer { SDL.quit() }

        let window = try SDLWindow(title: "Matter Color", frame: (.centered, .centered, width: 300, height: 300))
        let renderer = try SDLRenderer(window: window)
        var running = true

        let colorBox = NIOLockedValueBox(ColorRequest(hue: 0, saturation: 0, brightness: 0))

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { try? group.syncShutdownGracefully() }

        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(ColorHTTPHandler { color in
                        colorBox.withLockedValue { $0 = color }
                    })
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

        let channel = try bootstrap.bind(host: "0.0.0.0", port: 8080).wait()
        print("Server running on http://localhost:8080")

        var event = SDL_Event()
        while running {
            while SDL_PollEvent(&event) != 0 {
                if event.type == SDL_QUIT.rawValue {
                    running = false
                }
            }

            let rgb = colorBox.withLockedValue { color in
                hsbToRGB(h: color.hue, s: color.saturation, b: color.brightness)
            }
            try renderer.setDrawColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: .max)
            try renderer.clear()
            renderer.present()
            SDL_Delay(16)
        }

        try channel.close().wait()
    }
}
