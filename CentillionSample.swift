import SwiftUI
import CentillionSDK

@main struct CentillionSampleApp: App {
    var body: some Scene { WindowGroup { SetupView() } }
}

struct SetupView: View {
    @State private var agentId = UserDefaults.standard.string(forKey: "agentId") ?? ""
    @State private var baseURL = UserDefaults.standard.string(forKey: "baseURL") ?? "https://app.cntillion.com/api/sdk"
    @State private var client: CentillionClient?
    var body: some View {
        if let client { ChatView(client: client) }
        else {
            NavigationStack {
                Form {
                    Section("Connect your agent") {
                        Text("Enable iOS SDK in your agent's Overview, then enter its ID and your Centillion app URL.")
                        TextField("Agent ID", text: $agentId).textInputAutocapitalization(.never).autocorrectionDisabled()
                        TextField("SDK base URL", text: $baseURL).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                        Button("Open support") { connect() }.disabled(agentId.isEmpty)
                    }
                }.navigationTitle("Centillion")
            }.task { if UserDefaults.standard.bool(forKey: "smoke") && !agentId.isEmpty { connect() } }
        }
    }
    private func connect() { client = CentillionClient(agentId: agentId.trimmingCharacters(in: .whitespaces), baseURL: baseURL.trimmingCharacters(in: .whitespaces)) }
}

struct ChatView: View {
    let client: CentillionClient
    @State private var conversation: ConversationState
    @State private var history: ConversationListState
    @State private var text = ""
    @State private var showingHistory = false
    @State private var report = ""
    init(client: CentillionClient) {
        self.client = client
        _conversation = State(initialValue: ConversationState(client: client))
        _history = State(initialValue: ConversationListState(client: client))
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !report.isEmpty { Text(report).font(.caption2).padding(10).frame(maxWidth: .infinity).background(.green.opacity(0.08)) }
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            if conversation.hasMoreHistory { Button("Load older messages") { Task { await conversation.loadMoreHistory() } } }
                            if conversation.messages.isEmpty {
                                Text("How can we help?").font(.title2.bold()).padding(.top, 36)
                                Text("Ask a question and get support right here in your app.").foregroundStyle(.secondary)
                            }
                            ForEach(conversation.messages) { message in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(message.role == "user" ? "You" : "Centillion").font(.caption.bold()).foregroundStyle(.secondary)
                                    Text(.init(message.text.isEmpty ? "Thinking…" : message.text)).textSelection(.enabled)
                                    if message.role == "assistant" && !conversation.isSending {
                                        Button("Retry", systemImage: "arrow.clockwise") { Task { await conversation.retry(messageId: message.id) } }.font(.caption)
                                    }
                                }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(message.role == "user" ? Color.indigo.opacity(0.09) : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                                    .id(message.id)
                            }
                        }.padding()
                    }.onChange(of: conversation.messages.last?.text) { _, _ in
                        if let id = conversation.messages.last?.id { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
                if let error = conversation.error { Text(error.localizedDescription).font(.caption).foregroundStyle(.red).padding(8) }
                Divider()
                HStack {
                    TextField("Ask a question", text: $text, axis: .vertical).lineLimit(1...5).padding(12).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                    Button("Send", systemImage: "arrow.up.circle.fill") { let message = text; text = ""; Task { await conversation.sendMessage(message) } }
                        .labelStyle(.iconOnly).font(.title).disabled(conversation.isSending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }.padding()
            }.navigationTitle("Centillion").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("History", systemImage: "clock") { showingHistory = true; Task { await history.load() } } }
                    ToolbarItem(placement: .topBarTrailing) { Button("New conversation", systemImage: "square.and.pencil") { conversation.clear() }.disabled(conversation.isSending) }
                }
                .sheet(isPresented: $showingHistory) {
                    NavigationStack {
                        List {
                            ForEach(history.conversations) { item in Button(item.title) { showingHistory = false; Task { await conversation.loadHistory(conversationId: item.id) } } }
                            if history.hasMore { Button("Load more") { Task { await history.loadMore() } } }
                            if let error = history.error { Text(error.localizedDescription).foregroundStyle(.red) }
                        }.navigationTitle("Conversations").toolbar { Button("Done") { showingHistory = false } }
                    }
                }
        }.task {
            client.tool("get_app_version") { _ in .object(["version": .string("1.0.0"), "platform": .string("iOS")]) }
            if UserDefaults.standard.bool(forKey: "smoke") { await smoke() }
        }
    }
    private func smoke() async {
        do {
            await conversation.sendMessage("What can Centillion help me with? Please answer briefly.")
            if let error = conversation.error { throw error }
            guard let id = conversation.conversationId else { throw SDKError(code: "TEST", message: "Missing conversation") }
            await conversation.loadHistory(conversationId: id, limit: 1)
            let older = conversation.hasMoreHistory
            await conversation.loadMoreHistory()
            guard older, let answer = conversation.messages.last(where: { $0.role == "assistant" }) else { throw SDKError(code: "TEST", message: "Missing history") }
            await conversation.retry(messageId: answer.id)
            if let error = conversation.error { throw error }
            await conversation.sendMessage("What is my app version? Use the native action.")
            if let error = conversation.error { throw error }
            guard !conversation.toolResults.isEmpty else { throw SDKError(code: "TEST", message: "Native tool did not run") }
            await history.load()
            if let error = history.error { throw error }
            report = "PASS · Stream · History · Retry · Native tool · \(history.conversations.count) conversations"
        } catch { report = "FAIL: \(error.localizedDescription)" }
        let url = URL.documentsDirectory.appending(path: "sdk-smoke.txt")
        try? report.write(to: url, atomically: true, encoding: .utf8)
    }
}
