import SwiftUI

struct ActivityLogView: View {
    var viewModel: MissionViewModel
    @State private var draft = ""
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                Divider()
                composer
            }
            .background(LighthouseBackground())
            .navigationTitle("Activity")
            .toolbarTitleDisplayMode(.large)
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: LHSpacing.sm) {
                    if viewModel.messages.isEmpty {
                        ContentUnavailableView(
                            "No Messages Yet",
                            systemImage: "bubble.left.and.bubble.right",
                            description: Text("Send a report or ask for guidance.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, LHSpacing.xxl)
                    } else {
                        ForEach(viewModel.messages, id: \.id) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, LHLayout.screenPadding)
                .padding(.vertical, LHSpacing.md)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: LHSpacing.sm) {
            TextField("Report or ask…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, LHSpacing.sm)
                .padding(.vertical, LHSpacing.xs)
                .background(
                    Color(.tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: LHLayout.composerCorner, style: .continuous)
                )
                .focused($isComposerFocused)

            Button {
                let text = draft
                draft = ""
                Task { await viewModel.sendMessage(text) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: LHLayout.dockButton - 4, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, LHLayout.screenPadding)
        .padding(.vertical, LHSpacing.sm)
        .background(.bar)
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        let isUser = message.role == "user"
        return HStack(alignment: .bottom, spacing: 0) {
            if isUser { Spacer(minLength: 56) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: LHSpacing.xxs) {
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(isUser ? Color.white : Color.primary)
                    .padding(.horizontal, LHSpacing.sm)
                    .padding(.vertical, LHSpacing.xs + 2)
                    .background(
                        isUser ? Color.accentColor : Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: LHLayout.bubbleCorner, style: .continuous)
                    )
                Text(message.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, LHSpacing.xxs)
            }
            if !isUser { Spacer(minLength: 56) }
        }
    }
}
