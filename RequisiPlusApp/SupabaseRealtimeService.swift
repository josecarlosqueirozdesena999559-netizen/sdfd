import Foundation

final class SupabaseRealtimeService {
    private let urlSession: URLSession
    private var webSocketTask: URLSessionWebSocketTask?
    private var heartbeatTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var isActive = false
    private var refCounter = 0

    private var accessToken: String = ""
    private var userId: String = ""
    private var onChange: @MainActor () -> Void = {}

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func start(session: UserSession, onChange: @escaping @MainActor () -> Void) {
        stop()

        self.accessToken = session.accessToken
        self.userId = session.user.id
        self.onChange = onChange
        self.isActive = true

        connect()
    }

    func stop() {
        isActive = false
        heartbeatTask?.cancel()
        reconnectTask?.cancel()
        heartbeatTask = nil
        reconnectTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    deinit {
        stop()
    }

    private func connect() {
        guard isActive else { return }

        let urlString = "wss://\(SupabaseConfig.url.host ?? "")/realtime/v1/websocket?apikey=\(SupabaseConfig.publishableKey)&vsn=1.0.0"
        guard let url = URL(string: urlString) else { return }

        let task = urlSession.webSocketTask(with: url)
        webSocketTask = task
        task.resume()

        sendJoin()
        listen()
        startHeartbeat()
    }

    private func sendJoin() {
        let payload = RealtimeMessage(
            topic: "realtime:materials-sync",
            event: "phx_join",
            payload: .object([
                "config": .object([
                    "broadcast": .object([
                        "ack": .bool(false),
                        "self": .bool(false)
                    ]),
                    "presence": .object([
                        "enabled": .bool(false)
                    ]),
                    "postgres_changes": .array([
                        .object([
                            "event": .string("*"),
                            "schema": .string("public"),
                            "table": .string("itens")
                        ]),
                        .object([
                            "event": .string("*"),
                            "schema": .string("public"),
                            "table": .string("usuarios"),
                            "filter": .string("auth_user_id=eq.\(userId)")
                        ])
                    ]),
                    "private": .bool(false)
                ]),
                "access_token": .string(accessToken)
            ]),
            ref: nextRef(),
            joinRef: nextRef()
        )

        send(message: payload)
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            guard let self else { return }
            while self.isActive {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard self.isActive else { return }

                let heartbeat = RealtimeMessage(
                    topic: "phoenix",
                    event: "heartbeat",
                    payload: .object([:]),
                    ref: self.nextRef(),
                    joinRef: nil
                )
                self.send(message: heartbeat)
            }
        }
    }

    private func listen() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                self.handle(message)
                self.listen()
            case .failure:
                self.scheduleReconnect()
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let envelope = try? JSONDecoder().decode(RealtimeMessage.self, from: data) else {
            return
        }

        if envelope.event == "postgres_changes" {
            Task { @MainActor in
                onChange()
            }
        }
    }

    private func send(message: RealtimeMessage) {
        guard let webSocketTask else { return }
        guard let data = try? JSONEncoder().encode(message),
              let text = String(data: data, encoding: .utf8) else {
            return
        }

        webSocketTask.send(.string(text)) { [weak self] error in
            if error != nil {
                self?.scheduleReconnect()
            }
        }
    }

    private func scheduleReconnect() {
        guard isActive else { return }
        guard reconnectTask == nil else { return }

        heartbeatTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil

        reconnectTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self.reconnectTask = nil
            self.connect()
        }
    }

    private func nextRef() -> String {
        refCounter += 1
        return String(refCounter)
    }
}

private struct RealtimeMessage: Codable {
    let topic: String
    let event: String
    let payload: JSONValue
    let ref: String?
    let joinRef: String?

    enum CodingKeys: String, CodingKey {
        case topic
        case event
        case payload
        case ref
        case joinRef = "join_ref"
    }
}
