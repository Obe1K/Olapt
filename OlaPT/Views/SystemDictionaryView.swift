import SwiftUI
import UIKit

/// Строка, которую можно передать в `.sheet(item:)`.
struct IdentifiedTerm: Identifiable {
    let text: String
    var id: String { return text }
}

/// Встроенный словарь iOS (работает без интернета, если словарь скачан в настройках iPhone).
/// Если слова нет, iOS сама предложит загрузить словари («Управлять»).
struct SystemDictionaryView: UIViewControllerRepresentable {
    let term: String

    func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
        return UIReferenceLibraryViewController(term: term)
    }

    func updateUIViewController(_ controller: UIReferenceLibraryViewController, context: Context) {}
}

/// Камера для съёмки текста.
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            parent.dismiss()
            if let image = image {
                parent.onImage(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// Раскладка «в строку с переносом» для кнопок-слов.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 8

    private struct Item {
        let index: Int
        let x: CGFloat
        let size: CGSize
    }

    private struct Row {
        var items: [Item] = []
        var y: CGFloat = 0
        var height: CGFloat = 0
        var width: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 10_000
        let rows = arrange(maxWidth: maxWidth, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = proposal.width ?? (rows.map { $0.width }.max() ?? 0)
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(maxWidth: bounds.width, subviews: subviews)
        for row in rows {
            for item in row.items {
                subviews[item.index].place(at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y),
                                           anchor: .topLeading,
                                           proposal: ProposedViewSize(item.size))
            }
        }
    }

    private func arrange(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        var x: CGFloat = 0
        var y: CGFloat = 0
        for (i, view) in subviews.enumerated() {
            var size = view.sizeThatFits(.unspecified)
            if size.width > maxWidth {
                size = view.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
                size.width = min(size.width, maxWidth)
            }
            if x > 0 && x + size.width > maxWidth {
                current.y = y
                rows.append(current)
                y += current.height + lineSpacing
                current = Row()
                x = 0
            }
            current.items.append(Item(index: i, x: x, size: size))
            x += size.width + spacing
            current.height = max(current.height, size.height)
            current.width = x - spacing
        }
        if !current.items.isEmpty {
            current.y = y
            rows.append(current)
        }
        return rows
    }
}
