import SwiftUI

struct MultiSelectionView<T: Hashable & Identifiable & CustomStringConvertible>: View {
    let options: [T]
    @Binding var selected: Set<T>

    init(options: [T], selected: Binding<Set<T>>) {
        self.options = options
        self._selected = selected
    }

    private func isSelected(_ option: T) -> Bool {
        selected.contains(option)
    }

    private func toggleSelection(_ option: T) {
        if isSelected(option) {
            selected.remove(option)
        } else {
            selected.insert(option)
        }
    }

    var body: some View {
        List {
            ForEach(options) { option in
                Button(action: {
                    toggleSelection(option)
                }) {
                    HStack {
                        Text(option.description)
                        Spacer()
                        if isSelected(option) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}
