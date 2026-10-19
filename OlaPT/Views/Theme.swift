import SwiftUI
import UIKit
import CoreText

// MARK: - Тема: мрачная готика в пикселях

/// Цвета и шрифты оформления: тёмный камень, старое золото, кровь.
enum Theme {
    // Камень
    static let background = Color(red: 13 / 255, green: 11 / 255, blue: 10 / 255)
    static let panel = Color(red: 27 / 255, green: 24 / 255, blue: 21 / 255)
    static let panelRaised = Color(red: 36 / 255, green: 32 / 255, blue: 28 / 255)
    static let panelDeep = Color(red: 10 / 255, green: 9 / 255, blue: 8 / 255)
    // Золото
    static let gold = Color(red: 201 / 255, green: 163 / 255, blue: 90 / 255)
    static let goldBright = Color(red: 227 / 255, green: 194 / 255, blue: 122 / 255)
    static let goldDark = Color(red: 94 / 255, green: 74 / 255, blue: 38 / 255)
    // Текст: пергамент
    static let text = Color(red: 232 / 255, green: 220 / 255, blue: 192 / 255)
    static let textDim = Color(red: 156 / 255, green: 143 / 255, blue: 120 / 255)
    // Кровь, мох, угли
    static let blood = Color(red: 122 / 255, green: 22 / 255, blue: 16 / 255)
    static let bloodBright = Color(red: 176 / 255, green: 42 / 255, blue: 30 / 255)
    static let red = Color(red: 222 / 255, green: 84 / 255, blue: 62 / 255)
    static let moss = Color(red: 128 / 255, green: 176 / 255, blue: 82 / 255)
    static let mossDark = Color(red: 36 / 255, green: 58 / 255, blue: 26 / 255)
    static let bloodDark = Color(red: 70 / 255, green: 18 / 255, blue: 14 / 255)
    static let ember = Color(red: 214 / 255, green: 132 / 255, blue: 52 / 255)

    static let pixelFontName = "Tiny5-Bold"
    static let pixelFontRegularName = "Tiny5-Regular"
    static let gothicFontName = "JacquardaBastarda9-Regular"

    /// Пиксельный шрифт для заголовков и кнопок (с поддержкой Dynamic Type).
    static func pixel(_ size: CGFloat, bold: Bool = true, relativeTo style: Font.TextStyle = .body) -> Font {
        return .custom(bold ? pixelFontName : pixelFontRegularName, size: size, relativeTo: style)
    }

    /// Готический шрифт для надписи «Olá PT».
    static func gothic(_ size: CGFloat) -> Font {
        return .custom(gothicFontName, size: size, relativeTo: .largeTitle)
    }

    static func uiPixel(_ size: CGFloat, bold: Bool = true) -> UIFont {
        return UIFont(name: bold ? pixelFontName : pixelFontRegularName, size: size)
            ?? UIFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
    }

    // MARK: Шрифты из приложения

    /// Регистрирует шрифты из папки Fonts (без правки Info.plist).
    static func registerFonts() {
        let names = ["Tiny5-Bold", "Tiny5-Regular", "JacquardaBastarda9-Regular"]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    // MARK: Системные панели

    static func configureAppearance() {
        let bg = UIColor(background)
        let goldUI = UIColor(gold)
        let goldBrightUI = UIColor(goldBright)
        let goldDarkUI = UIColor(goldDark)
        let dimUI = UIColor(textDim)

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = bg
        nav.shadowColor = goldDarkUI
        nav.titleTextAttributes = [.font: uiPixel(20), .foregroundColor: goldBrightUI]
        nav.largeTitleTextAttributes = [.font: uiPixel(32), .foregroundColor: goldBrightUI]
        let barButton = UIBarButtonItemAppearance()
        barButton.normal.titleTextAttributes = [.font: uiPixel(15, bold: false), .foregroundColor: goldUI]
        nav.buttonAppearance = barButton
        nav.backButtonAppearance = barButton
        nav.doneButtonAppearance = barButton
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = goldUI

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(red: 8 / 255, green: 7 / 255, blue: 6 / 255, alpha: 1)
        tab.shadowColor = goldDarkUI
        for layout in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            layout.normal.iconColor = dimUI
            layout.normal.titleTextAttributes = [.font: uiPixel(10, bold: false), .foregroundColor: dimUI]
            layout.selected.iconColor = goldBrightUI
            layout.selected.titleTextAttributes = [.font: uiPixel(10), .foregroundColor: goldBrightUI]
            layout.normal.badgeBackgroundColor = UIColor(bloodBright)
            layout.normal.badgeTextAttributes = [.font: uiPixel(11), .foregroundColor: UIColor(text)]
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        let seg = UISegmentedControl.appearance()
        seg.selectedSegmentTintColor = UIColor(blood)
        seg.backgroundColor = UIColor(panelDeep)
        seg.setTitleTextAttributes([.font: uiPixel(13, bold: false), .foregroundColor: dimUI], for: .normal)
        seg.setTitleTextAttributes([.font: uiPixel(13), .foregroundColor: UIColor(text)], for: .selected)

        UISwitch.appearance().onTintColor = UIColor(blood)
        UISwitch.appearance().thumbTintColor = UIColor(text)
    }
}

// MARK: - Каменная стена

/// Фон: тёмная кладка, пиксели по 2 pt.
struct StoneBackground: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.background))
            let u: CGFloat = 2
            let bw: CGFloat = 24
            let bh: CGFloat = 12
            let shades = [
                Color(red: 16 / 255, green: 14 / 255, blue: 13 / 255),
                Color(red: 19 / 255, green: 17 / 255, blue: 15 / 255),
                Color(red: 22 / 255, green: 19 / 255, blue: 17 / 255),
            ]
            var paths = [Path(), Path(), Path()]
            var chips = Path()
            let rows = Int(size.height / bh) + 2
            let cols = Int(size.width / bw) + 2
            for row in 0..<rows {
                let off: CGFloat = row % 2 == 1 ? bw / 2 : 0
                for col in -1..<cols {
                    // детерминированный «случай»: одинаковый узор при каждой перерисовке
                    let h = (row &* 73_856_093) ^ (col &* 19_349_663)
                    let shade = abs(h) % 4 == 0 ? 2 : (abs(h) % 3 == 0 ? 1 : 0)
                    let x = CGFloat(col) * bw + off
                    let y = CGFloat(row) * bh
                    paths[shade].addRect(CGRect(x: x + u, y: y + u, width: bw - u, height: bh - u))
                    if abs(h) % 5 == 0 {
                        let cx = x + CGFloat(2 + abs(h / 7) % 9) * u
                        let cy = y + CGFloat(2 + abs(h / 11) % 3) * u
                        chips.addRect(CGRect(x: cx, y: cy, width: u, height: u))
                    }
                }
            }
            for i in 0..<3 {
                context.fill(paths[i], with: .color(shades[i]))
            }
            context.fill(chips, with: .color(Color(red: 28 / 255, green: 25 / 255, blue: 22 / 255)))
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Пиксельная рамка

/// Панель со «ступенчатыми» углами и золотой рамкой в 2 пикселя.
struct PixelFrame: View {
    var fill: Color = Theme.panel
    var border: Color = Theme.gold
    var highlight: Color = Theme.goldBright
    var shadow: Color = Theme.goldDark
    var unit: CGFloat = 2

    var body: some View {
        Canvas { context, size in
            let u = unit
            let w = size.width
            let h = size.height
            context.fill(Path(CGRect(x: u, y: u, width: w - 2 * u, height: h - 2 * u)), with: .color(fill))
            // стороны без углов
            context.fill(Path(CGRect(x: u, y: 0, width: w - 2 * u, height: u)), with: .color(highlight))
            context.fill(Path(CGRect(x: u, y: h - u, width: w - 2 * u, height: u)), with: .color(shadow))
            context.fill(Path(CGRect(x: 0, y: u, width: u, height: h - 2 * u)), with: .color(border))
            context.fill(Path(CGRect(x: w - u, y: u, width: u, height: h - 2 * u)), with: .color(border))
            // внутренние уголки
            for p in [CGPoint(x: u, y: u), CGPoint(x: w - 2 * u, y: u),
                      CGPoint(x: u, y: h - 2 * u), CGPoint(x: w - 2 * u, y: h - 2 * u)] {
                context.fill(Path(CGRect(x: p.x, y: p.y, width: u, height: u)), with: .color(border))
            }
            // тень под верхней кромкой
            context.fill(Path(CGRect(x: 2 * u, y: u, width: w - 4 * u, height: u / 2)), with: .color(.black))
        }
        .accessibilityHidden(true)
    }
}

extension View {
    /// Содержимое в пиксельной рамке.
    func pixelPanel(fill: Color = Theme.panel, border: Color = Theme.gold, padding: CGFloat = 14) -> some View {
        return self
            .padding(padding)
            .background(PixelFrame(fill: fill, border: border))
    }

    /// Экран со списком: каменная стена вместо системного фона.
    func gothicScreen() -> some View {
        return self
            .scrollContentBackground(.hidden)
            .background(StoneBackground().ignoresSafeArea())
    }
}

// MARK: - Список и форма

/// Список на каменном фоне; строки — тёмные плиты.
struct GothicList<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        List {
            Group {
                content
            }
            .listRowBackground(Theme.panel)
            .listRowSeparatorTint(Theme.goldDark)
        }
        .gothicScreen()
    }
}

/// Форма (настройки) на каменном фоне.
struct GothicForm<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        Form {
            Group {
                content
            }
            .listRowBackground(Theme.panel)
            .listRowSeparatorTint(Theme.goldDark)
        }
        .gothicScreen()
    }
}

// MARK: - Заголовок раздела

/// Заголовок раздела: золотые пиксельные буквы между ромбиками.
struct GothicHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        HStack(spacing: 6) {
            Diamond()
                .fill(Theme.gold)
                .frame(width: 6, height: 6)
            Text(title)
                .font(Theme.pixel(13, relativeTo: .footnote))
                .foregroundColor(Theme.gold)
                .textCase(.uppercase)
            Rectangle()
                .fill(Theme.goldDark)
                .frame(height: 2)
        }
        .padding(.top, 4)
    }
}

struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Кнопки

/// Кнопки: главная — кровавая плита в золотой рамке, обычная — каменная.
struct GothicButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    var kind: Kind = .primary
    @Environment(\.isEnabled) private var isEnabled

    init(_ kind: Kind = .primary) {
        self.kind = kind
    }

    func makeBody(configuration: Configuration) -> some View {
        let fill: Color
        switch kind {
        case .primary: fill = configuration.isPressed ? Theme.bloodBright : Theme.blood
        case .secondary: fill = configuration.isPressed ? Theme.panelRaised : Theme.panel
        }
        return configuration.label
            .font(Theme.pixel(17, relativeTo: .headline))
            .foregroundColor(isEnabled ? Theme.text : Theme.textDim)
            .multilineTextAlignment(.center)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(PixelFrame(fill: isEnabled ? fill : Theme.panelDeep,
                                   border: isEnabled ? Theme.gold : Theme.goldDark,
                                   highlight: isEnabled ? Theme.goldBright : Theme.goldDark))
            .offset(y: configuration.isPressed ? 1 : 0)
    }
}

// MARK: - Полоска прогресса

/// Пиксельная полоска: золото по чёрному в рамке.
struct PixelProgressBar: View {
    let fraction: Double
    var fill: Color = Theme.gold
    /// Цвет полностью заполненной полоски (nil — тот же, что и fill; для здоровья босса)
    var doneFill: Color? = Theme.moss
    var height: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            // рамка PixelFrame — 1 «пиксель» (2 pt), заливка отступает от неё ещё на 1
            let u: CGFloat = 2
            let inset = 2 * u
            let inner = max(0, geo.size.width - 2 * inset)
            let f = CGFloat(min(1, max(0, fraction)))
            // ширина кратна «пикселю», но непустая доля видна хотя бы одним «пикселем»
            let steps = (inner * f / u).rounded(.down)
            let width = f > 0 ? max(u, steps * u) : 0
            ZStack(alignment: .topLeading) {
                PixelFrame(fill: Theme.panelDeep, border: Theme.goldDark, highlight: Theme.goldDark, shadow: Theme.goldDark)
                Rectangle()
                    .fill(fraction >= 1 ? (doneFill ?? fill) : fill)
                    .frame(width: width, height: max(0, geo.size.height - 2 * inset))
                    .offset(x: inset, y: inset)
                    .animation(.easeOut(duration: 0.25), value: fraction)
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityValue("\(Int(fraction * 100)) %")
    }
}
