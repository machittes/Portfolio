import SwiftUI

struct Collapsible<Content: View>: View {
    @State var label: () -> Text
    @State var content: () -> Content
    @State private var collapsed: Bool = true

    var body: some View {
        VStack {
            Button(action: {
                self.collapsed.toggle()
            }) {
                HStack {
                    self.label()
                        .font(.headline)
                        .fontWeight(.bold)
                    Spacer()
                    Image(systemName: self.collapsed ? "chevron.down" : "chevron.up")
                        .foregroundColor(.accentColor)
                }
                .padding(.bottom, 1)
                .background(Color.white.opacity(0.01))
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if !collapsed {
                content()
                    .padding(.top, 5)
            }
        }
        .padding(.bottom, 5)
    }
}
