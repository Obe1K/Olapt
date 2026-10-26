import CoreGraphics

// Создано Tools/game/build_game_assets.py — не править руками.
/// Метки на карте: размер холста в точках карты. Точка «на земле» — в центре холста.
enum MapMarks {
    static let size: [String: CGSize] = [
        "fx_fire": CGSize(width: 15.0, height: 44.0),
        "map_legion": CGSize(width: 50.3, height: 47.7),
        "map_patrol": CGSize(width: 31.3, height: 59.3),
        "obelisk_broken": CGSize(width: 24.3, height: 40.3),
        "obelisk_dark": CGSize(width: 13.0, height: 54.0),
        "obelisk_lit": CGSize(width: 21.3, height: 57.3),
    ]

    static func size(_ name: String) -> CGSize {
        return size[name] ?? CGSize(width: 10, height: 10)
    }
}
