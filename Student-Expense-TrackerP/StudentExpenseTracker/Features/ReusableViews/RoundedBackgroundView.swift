import SwiftUI

struct RoundedBottomTabView: View {
    var body: some View {
        HStack {
            Image(systemName: "house.fill")
            Spacer()
            Image(systemName: "chart.bar.fill")
            Spacer()
            Image(systemName: "square.stack.3d.up.fill")
            Spacer()
            Image(systemName: "person.fill")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(30)
        .shadow(radius: 5)
        .padding(.horizontal, 20)
    }
}
