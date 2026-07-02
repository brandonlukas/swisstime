import SwiftUI

struct ActionItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    var destructive: Bool = false
    let action: () -> Void
}

/// Bottom sheet with a plain list of actions and a Cancel button,
/// matching the app's flat style.
struct ActionListSheet: View {
    @Environment(\.dismiss) private var dismiss
    let actions: [ActionItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(actions) { item in
                Button {
                    item.action()
                    dismiss()
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: item.icon)
                            .font(.system(size: 18))
                        Text(item.title)
                            .font(.app(17))
                    }
                    .foregroundStyle(item.destructive ? Color.brick : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 64)
                }
                .buttonStyle(.plain)
            }
            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.app(17))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
        }
        .padding(20)
        .presentationBackground(Color.paper)
        .presentationDetents([.height(CGFloat(actions.count) * 64 + 150)])
        .presentationDragIndicator(.visible)
    }
}
