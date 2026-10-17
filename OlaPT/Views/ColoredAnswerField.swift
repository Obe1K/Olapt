import SwiftUI
import UIKit

/// Поле ответа, в котором буквы окрашиваются прямо при вводе:
/// зелёные — пока ввод совпадает с началом правильного ответа, красные — начиная с первой ошибки.
/// Пример: ответ «curto»; ввод «cu» — обе буквы зелёные, ввод «k» — красная.
struct ColoredAnswerField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let placeholder: String
    let isEnabled: Bool
    /// Сколько первых символов ввода верны.
    let correctPrefix: (String) -> Int
    let onSubmit: () -> Void

    /// Тёмно-зелёный на светлом фоне (системный зелёный слишком светлый для текста), обычный — на тёмном.
    static let goodColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.systemGreen
            : UIColor(red: 0.10, green: 0.55, blue: 0.22, alpha: 1)
    }
    static let badColor = UIColor.systemRed

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.font = UIFont.preferredFont(forTextStyle: .title2)
        field.adjustsFontForContentSizeCategory = true
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.smartInsertDeleteType = .no
        field.returnKeyType = .done
        field.borderStyle = .roundedRect
        field.clearButtonMode = .whileEditing
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.accessibilityIdentifier = "answer-field"
        field.accessibilityLabel = placeholder
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if (field.text ?? "") != text {
            field.text = text
            context.coordinator.recolor(field)
        }
        field.isEnabled = isEnabled
        if isFocused && isEnabled && !field.isFirstResponder {
            DispatchQueue.main.async { field.becomeFirstResponder() }
        } else if !isFocused && field.isFirstResponder {
            DispatchQueue.main.async { field.resignFirstResponder() }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: ColoredAnswerField

        init(_ parent: ColoredAnswerField) {
            self.parent = parent
        }

        @objc func changed(_ field: UITextField) {
            parent.text = field.text ?? ""
            recolor(field)
        }

        /// Перекрашивает весь текст: верная часть — зелёным, остальное — красным.
        func recolor(_ field: UITextField) {
            // Пока система собирает символ (например, диакритика через отдельную клавиатуру),
            // текст не трогаем, иначе ввод собьётся.
            if field.markedTextRange != nil { return }
            let value = field.text ?? ""
            let font = field.font ?? UIFont.preferredFont(forTextStyle: .title2)
            let good = min(parent.correctPrefix(value), value.count)
            let goodLength = String(value.prefix(good)).utf16.count
            let total = (value as NSString).length

            let attributed = NSMutableAttributedString(string: value, attributes: [
                .font: font,
                .foregroundColor: UIColor.label
            ])
            if goodLength > 0 {
                attributed.addAttribute(.foregroundColor, value: ColoredAnswerField.goodColor,
                                        range: NSRange(location: 0, length: goodLength))
            }
            if total > goodLength {
                attributed.addAttribute(.foregroundColor, value: ColoredAnswerField.badColor,
                                        range: NSRange(location: goodLength, length: total - goodLength))
            }
            let selection = field.selectedTextRange
            field.attributedText = attributed
            if let selection = selection {
                field.selectedTextRange = selection
            }
            // Следующая буква по умолчанию цвета «ещё не проверено», её окрасит следующий вызов.
            field.typingAttributes = [.font: font, .foregroundColor: UIColor.label]
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            parent.onSubmit()
            return false
        }

        func textFieldDidBeginEditing(_ field: UITextField) {
            if !parent.isFocused {
                DispatchQueue.main.async { self.parent.isFocused = true }
            }
        }

        func textFieldDidEndEditing(_ field: UITextField) {
            if parent.isFocused {
                DispatchQueue.main.async { self.parent.isFocused = false }
            }
        }
    }
}
