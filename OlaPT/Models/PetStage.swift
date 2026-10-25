import Foundation

// MARK: - Слой пиксельной сцены

/// Слой, поставленный на сцену: картинка и её левый верхний угол в пикселях сцены
/// (зал башни — 320×200, арена босса — 192×120).
struct PlacedLayer: Identifiable {
    let id: Int
    let name: String
    let x: Int
    let y: Int
    let w: Int
    let h: Int
}
