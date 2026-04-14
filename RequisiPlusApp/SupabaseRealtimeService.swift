import Foundation

final class SupabaseRealtimeService {
    enum Event {
        case postgresChange(String?)
        case chatTyping(threadId: String, senderUserId: String, senderName: String, isTyping: Bool)
    }

    struct Subscription {
        let topic: String
        let postgresChanges: [PostgresChange]
    }

    struct PostgresChange {
        let event: String
        let schema: String
        let table: String
        let filter: String?
    }

    private let urlSession: URLSession
    private var webSocketTask: URLSessionWebSocketTask?
    private var heartbeatTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var isActive = false
    private var refCounter = 0

    private var accessToken: String = ""
    private var userId: String = ""
    private var subscriptions: [Subscription] = []
    private var onEvent: @MainActor (Event) -> Void = { _ in }

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func start(
        session: UserSession,
        subscriptions: [Subscription],
        onEvent: @escaping @MainActor (Event) -> Void
    ) {
        stop()

        self.accessToken = session.accessToken
        self.userId = session.user.id
        self.subscriptions = subscriptions
        self.onEvent = onEvent
        self.isActive = true

        connect()
    }

    func sendChatTyping(threadId: String, senderUserId: String, senderName: String, isTyping: Bool) {
        let message = RealtimeMessage(
            topic: "realtime:chat-data",
            event: "broadcast",
            payload: .object([
                "event": .string("chat_typing"),
                "payload": .object([
                    "thread_id": .string(threadId),
                    "sender_user_id": .string(senderUserId),
                    "sender_name": .string(senderName),
                    "is_typing": .bool(isTyping)
                ])
            ]),
            ref: nextRef(),
            joinRef: nil
        )
        send(message: message)
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

        sendJoins()
        listen()
        startHeartbeat()
    }

    private func sendJoins() {
        for subscription in subscriptions {
            let joinRef = nextRef()
            let payload = RealtimeMessage(
                topic: subscription.topic,
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
                        "postgres_changes": .array(
                            subscription.postgresChanges.map { change in
                                var object: [String: JSONValue] = [
                                    "event": .string(change.event),
                                    "schema": .string(change.schema),
                                    "table": .string(change.table)
                                ]

                                if let filter = change.filter {
                                    object["filter"] = .string(filter)
                                }

                                return .object(object)
                            }
                        ),
                        "private": .bool(false)
                    ]),
                    "access_token": .string(accessToken)
                ]),
                ref: nextRef(),
                joinRef: joinRef
            )

            send(message: payload)
        }
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
            let changedTable = envelope.payload.objectValue?["data"]?.objectValue?["table"]?.stringValue
            Task { @MainActor in
                onEvent(.postgresChange(changedTable))
            }
        } else if envelope.event == "broadcast" {
            handleBroadcast(envelope.payload)
        } else if envelope.event == "phx_error" || envelope.event == "phx_close" {
            scheduleReconnect()
        }
    }

    private func handleBroadcast(_ payload: JSONValue) {
        guard let payloadObject = payload.objectValue,
              payloadObject["event"]?.stringValue == "chat_typing",
              let eventPayload = payloadObject["payload"]?.objectValue,
              let threadId = eventPayload["thread_id"]?.stringValue,
              let senderUserId = eventPayload["sender_user_id"]?.stringValue,
              let senderName = eventPayload["sender_name"]?.stringValue,
              let isTyping = eventPayload["is_typing"]?.boolValue else {
            return
        }

        Task { @MainActor in
            onEvent(.chatTyping(threadId: threadId, senderUserId: senderUserId, senderName: senderName, isTyping: isTyping))
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

private extension JSONValue {
    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self {
            return value
        }
        return nil
    }
}
