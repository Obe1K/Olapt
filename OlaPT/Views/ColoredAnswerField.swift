import SwiftUI
import UIKit

/// Поле ответа, в котором буквы окрашиваются прямо при вводе:
/// зелёные — пока ввод совпадает с началом правильного ответа, золотые — буква верная, но без акцента,
/// красные — начиная с первой ошибки.
/// Пример: ответ «lição»; ввод «lic» — «l», «i» зелёные, «c» золотая (нужна «ç»).
struct ColoredAnswerField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let placeholder: String
    let isEnabled: Bool
    /// Сколько первых символов ввода верны и где не хватает акцента.
    let coloring: (String) -> AnswerColoring
    let onSubmit: () -> Void

    /// Мох — пока верно, кровь — с места ошибки (приложение всегда в тёмной теме).
    static let goodColor = UIColor(Theme.moss)
    static let badColor = UIColor(Theme.red)
    static let accentColor = UIColor(Theme.goldBright)
    static let baseColor = UIColor(Theme.text)

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.attributedPlaceholder = NSAttributedString(string: placeholder,
                                                         attributes: [.foregroundColor: UIColor(Theme.textDim)])
        field.textColor = ColoredAnswerField.baseColor
        field.tintColor = UIColor(Theme.gold)
        field.keyboardAppearance = .dark
        field.font = UIFont.preferredFont(forTextStyle: .title2)
        field.adjustsFontForContentSizeCategory = true
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.smartInsertDeleteType = .no
        field.returnKeyType = .done
        field.borderStyle = .none
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

        /// Перекрашивает весь текст: верная часть — зелёным (без акцента — золотым), остальное — красным.
        func recolor(_ field: UITextField) {
            // Пока система собирает символ (например, диакритика через отдельную клавиатуру),
            // текст не трогаем, иначе ввод собьётся.
            if field.markedTextRange != nil { return }
            let value = field.text ?? ""
            let font = field.font ?? UIFont.preferredFont(forTextStyle: .title2)
            let marks = parent.coloring(value)
            let good = min(marks.prefix, value.count)
            let goodLength = String(value.prefix(good)).utf16.count
            let total = (value as NSString).length

            let attributed = NSMutableAttributedString(string: value, attributes: [
                .font: font,
                .foregroundColor: ColoredAnswerField.baseColor
            ])
            if goodLength > 0 {
                attributed.addAttribute(.foregroundColor, value: ColoredAnswerField.goodColor,
                                        range: NSRange(location: 0, length: goodLength))
            }
            if total > goodLength {
                attributed.addAttribute(.foregroundColor, value: ColoredAnswerField.badColor,
                                        range: NSRange(location: goodLength, length: total - goodLength))
            }
            // Буквы без нужного акцента — золотые и подчёркнутые
            for index in marks.accentSlips where index < good {
                let start = value.index(value.startIndex, offsetBy: index)
                let range = NSRange(start...start, in: value)
                attributed.addAttribute(.foregroundColor, value: ColoredAnswerField.accentColor, range: range)
                attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
            let selection = field.selectedTextRange
            field.attributedText = attributed
            if let selection = selection {
                field.selectedTextRange = selection
            }
            // Следующая буква по умолчанию цвета «ещё не проверено», её окрасит следующий вызов.
            field.typingAttributes = [.font: font, .foregroundColor: ColoredAnswerField.baseColor]
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
