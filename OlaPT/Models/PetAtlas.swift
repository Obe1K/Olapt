// Сгенерировано Tools/pet/export_hires.py — не редактировать вручную.

/// Слой сцены: картинка из Assets/Pet и её место на экране 192×120.
struct PetLayer {
    let name: String
    let x: Int
    let y: Int
    let w: Int
    let h: Int
}

enum PetAtlas {
    static let width = 192
    static let height = 120

    static let layers: [String: PetLayer] = [
        "pet_bg_cellar": PetLayer(name: "pet_bg_cellar", x: 0, y: 0, w: 192, h: 120),
        "pet_bg_dungeon": PetLayer(name: "pet_bg_dungeon", x: 0, y: 0, w: 192, h: 120),
        "pet_bg_dungeon_chained": PetLayer(name: "pet_bg_dungeon_chained", x: 0, y: 0, w: 192, h: 120),
        "pet_bg_hall": PetLayer(name: "pet_bg_hall", x: 0, y: 0, w: 192, h: 120),
        "pet_bg_library": PetLayer(name: "pet_bg_library", x: 0, y: 0, w: 192, h: 120),
        "pet_bg_summit": PetLayer(name: "pet_bg_summit", x: 0, y: 0, w: 192, h: 120),
        "pet_book": PetLayer(name: "pet_book", x: 103, y: 46, w: 36, h: 21),
        "pet_candle0_lit0": PetLayer(name: "pet_candle0_lit0", x: 0, y: -16, w: 4, h: 17),
        "pet_candle0_lit1": PetLayer(name: "pet_candle0_lit1", x: 0, y: -16, w: 4, h: 17),
        "pet_candle0_lit2": PetLayer(name: "pet_candle0_lit2", x: 0, y: -16, w: 4, h: 17),
        "pet_candle0_lit3": PetLayer(name: "pet_candle0_lit3", x: 0, y: -16, w: 4, h: 17),
        "pet_candle0_out0": PetLayer(name: "pet_candle0_out0", x: 0, y: -21, w: 4, h: 22),
        "pet_candle0_out1": PetLayer(name: "pet_candle0_out1", x: 0, y: -21, w: 4, h: 22),
        "pet_candle1_lit0": PetLayer(name: "pet_candle1_lit0", x: 0, y: -19, w: 4, h: 20),
        "pet_candle1_lit1": PetLayer(name: "pet_candle1_lit1", x: 0, y: -19, w: 4, h: 20),
        "pet_candle1_lit2": PetLayer(name: "pet_candle1_lit2", x: 0, y: -19, w: 4, h: 20),
        "pet_candle1_lit3": PetLayer(name: "pet_candle1_lit3", x: 0, y: -19, w: 4, h: 20),
        "pet_candle1_out0": PetLayer(name: "pet_candle1_out0", x: 0, y: -24, w: 4, h: 25),
        "pet_candle1_out1": PetLayer(name: "pet_candle1_out1", x: 0, y: -24, w: 4, h: 25),
        "pet_candle_light": PetLayer(name: "pet_candle_light", x: -24, y: -24, w: 48, h: 48),
        "pet_curse0": PetLayer(name: "pet_curse0", x: 80, y: 10, w: 55, h: 29),
        "pet_curse1": PetLayer(name: "pet_curse1", x: 80, y: 10, w: 55, h: 29),
        "pet_curse2": PetLayer(name: "pet_curse2", x: 80, y: 10, w: 60, h: 29),
        "pet_curse3": PetLayer(name: "pet_curse3", x: 80, y: 10, w: 55, h: 29),
        "pet_curse4": PetLayer(name: "pet_curse4", x: 80, y: 10, w: 63, h: 29),
        "pet_curse5": PetLayer(name: "pet_curse5", x: 80, y: 10, w: 55, h: 29),
        "pet_curse_shout": PetLayer(name: "pet_curse_shout", x: 80, y: 10, w: 31, h: 29),
        "pet_drop": PetLayer(name: "pet_drop", x: 70, y: 0, w: 2, h: 4),
        "pet_fire0": PetLayer(name: "pet_fire0", x: 15, y: 73, w: 22, h: 16),
        "pet_fire1": PetLayer(name: "pet_fire1", x: 15, y: 73, w: 22, h: 16),
        "pet_fire2": PetLayer(name: "pet_fire2", x: 15, y: 73, w: 22, h: 16),
        "pet_heart": PetLayer(name: "pet_heart", x: 102, y: 14, w: 8, h: 6),
        "pet_item_armor0": PetLayer(name: "pet_item_armor0", x: 148, y: 54, w: 19, h: 40),
        "pet_item_banner0": PetLayer(name: "pet_item_banner0", x: 102, y: 6, w: 27, h: 35),
        "pet_item_cat0": PetLayer(name: "pet_item_cat0", x: 44, y: 102, w: 14, h: 9),
        "pet_item_cat1": PetLayer(name: "pet_item_cat1", x: 44, y: 102, w: 14, h: 9),
        "pet_item_cauldron0": PetLayer(name: "pet_item_cauldron0", x: 14, y: 92, w: 27, h: 22),
        "pet_item_cauldron1": PetLayer(name: "pet_item_cauldron1", x: 14, y: 93, w: 27, h: 21),
        "pet_item_circle0": PetLayer(name: "pet_item_circle0", x: 64, y: 104, w: 64, h: 14),
        "pet_item_circle1": PetLayer(name: "pet_item_circle1", x: 64, y: 104, w: 64, h: 14),
        "pet_item_crystal0": PetLayer(name: "pet_item_crystal0", x: 173, y: 76, w: 17, h: 24),
        "pet_item_crystal1": PetLayer(name: "pet_item_crystal1", x: 173, y: 76, w: 17, h: 24),
        "pet_item_hourglass0": PetLayer(name: "pet_item_hourglass0", x: 50, y: 9, w: 9, h: 13),
        "pet_item_hourglass1": PetLayer(name: "pet_item_hourglass1", x: 50, y: 9, w: 9, h: 13),
        "pet_item_hourglass2": PetLayer(name: "pet_item_hourglass2", x: 50, y: 9, w: 9, h: 13),
        "pet_item_raven0": PetLayer(name: "pet_item_raven0", x: 172, y: 61, w: 13, h: 13),
        "pet_item_raven1": PetLayer(name: "pet_item_raven1", x: 172, y: 61, w: 13, h: 13),
        "pet_item_staff0": PetLayer(name: "pet_item_staff0", x: 50, y: 41, w: 7, h: 52),
        "pet_item_starmap0": PetLayer(name: "pet_item_starmap0", x: 66, y: 4, w: 30, h: 18),
        "pet_mage_angry0": PetLayer(name: "pet_mage_angry0", x: 51, y: 20, w: 40, h: 74),
        "pet_mage_angry1": PetLayer(name: "pet_mage_angry1", x: 50, y: 20, w: 42, h: 74),
        "pet_mage_drink": PetLayer(name: "pet_mage_drink", x: 59, y: 25, w: 48, h: 70),
        "pet_mage_read": PetLayer(name: "pet_mage_read", x: 59, y: 25, w: 52, h: 70),
        "pet_mage_read2": PetLayer(name: "pet_mage_read2", x: 59, y: 25, w: 52, h: 70),
        "pet_mage_tired": PetLayer(name: "pet_mage_tired", x: 61, y: 27, w: 42, h: 68),
        "pet_mage_wave": PetLayer(name: "pet_mage_wave", x: 59, y: 25, w: 54, h: 70),
        "pet_page_turn": PetLayer(name: "pet_page_turn", x: 105, y: 42, w: 12, h: 9),
        "pet_rat0": PetLayer(name: "pet_rat0", x: 0, y: 104, w: 22, h: 10),
        "pet_rat1": PetLayer(name: "pet_rat1", x: 0, y: 104, w: 22, h: 10),
        "pet_sigh": PetLayer(name: "pet_sigh", x: 96, y: 40, w: 24, h: 29),
        "pet_skeleton0": PetLayer(name: "pet_skeleton0", x: 38, y: 56, w: 52, h: 58),
        "pet_skeleton1": PetLayer(name: "pet_skeleton1", x: 38, y: 56, w: 52, h: 58),
        "pet_sparks0": PetLayer(name: "pet_sparks0", x: 105, y: 21, w: 29, h: 22),
        "pet_sparks1": PetLayer(name: "pet_sparks1", x: 105, y: 18, w: 30, h: 30),
        "pet_sparks2": PetLayer(name: "pet_sparks2", x: 105, y: 25, w: 29, h: 22),
        "pet_splash": PetLayer(name: "pet_splash", x: 67, y: 92, w: 7, h: 3),
        "pet_thought": PetLayer(name: "pet_thought", x: 93, y: 0, w: 28, h: 28)
    ]

    /// Вещи в башне за выученные слова: порог, ключ, название.
    static let items: [(threshold: Int, key: String, title: String)] = [
        (50, "cauldron", "Котёл с зельем"),
        (100, "raven", "Ворон"),
        (150, "crystal", "Хрустальный шар"),
        (200, "starmap", "Карта звёзд"),
        (250, "hourglass", "Песочные часы"),
        (300, "cat", "Чёрный кот"),
        (350, "staff", "Посох"),
        (400, "banner", "Знамя"),
        (450, "armor", "Доспехи"),
        (500, "circle", "Магический круг")
    ]
}
