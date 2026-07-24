import SwiftUI
import SwiftChatCore

struct CustomToolCardExample: View {
    private let call = SwiftChatToolCall(
        name: "host.lookup",
        arguments: #"{"query":"Swift Package"}"#,
        state: .success
    )

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wrench.and.screwdriver")
            VStack(alignment: .leading, spacing: 2) {
                Text(call.name).font(.caption.bold())
                Text("Custom host tool card • \(call.state.rawValue)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
