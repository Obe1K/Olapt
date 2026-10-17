import Foundation

// MARK: - Спрайты

/// Спрайт из 4 оттенков: '0' чёрный, '1' тёмно-серый, '2' серый, '3' костяной белый, '.' — прозрачно.
struct PetSprite {
    static let transparent: UInt8 = 255
    let width: Int
    let height: Int
    let pixels: [UInt8]

    init(rows: [String]) {
        let w = rows.map { $0.utf8.count }.max() ?? 0
        var px = Array(repeating: PetSprite.transparent, count: w * rows.count)
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.utf8.enumerated() where ch >= 48 && ch <= 51 {
                px[y * w + x] = ch - 48
            }
        }
        width = w
        height = rows.count
        pixels = px
    }
}

// MARK: - Пиксельный экран

/// Экран 96×60, по пикселю — номер оттенка 0…3.
struct PixelBuffer {
    let width: Int
    let height: Int
    private(set) var pixels: [UInt8]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.pixels = Array(repeating: 0, count: width * height)
    }

    func value(_ x: Int, _ y: Int) -> UInt8 {
        guard x >= 0, y >= 0, x < width, y < height else { return 0 }
        return pixels[y * width + x]
    }

    mutating func set(_ x: Int, _ y: Int, _ v: UInt8) {
        guard x >= 0, y >= 0, x < width, y < height else { return }
        pixels[y * width + x] = v
    }

    mutating func stamp(_ sprite: PetSprite, x: Int, y: Int) {
        for sy in 0..<sprite.height {
            let ty = y + sy
            if ty < 0 || ty >= height { continue }
            for sx in 0..<sprite.width {
                let v = sprite.pixels[sy * sprite.width + sx]
                if v == PetSprite.transparent { continue }
                let tx = x + sx
                if tx < 0 || tx >= width { continue }
                pixels[ty * width + tx] = v
            }
        }
    }

    mutating func fill(x0: Int, y0: Int, x1: Int, y1: Int, _ v: UInt8) {
        if x1 < x0 || y1 < y0 { return }
        for yy in y0...y1 {
            for xx in x0...x1 {
                set(xx, yy, v)
            }
        }
    }

    static func runesWidth(_ runes: [Int]) -> Int {
        if runes.isEmpty { return 0 }
        var w = 0
        for i in runes {
            w += PetSprites.runes[i % PetSprites.runes.count].width + 2
        }
        return w - 2
    }

    /// Облачко с рунами; хвостик внизу слева.
    mutating func runeBubble(_ runes: [Int], x: Int, y: Int) {
        let w = PixelBuffer.runesWidth(runes) + 8
        let h = 13
        fill(x0: x, y0: y, x1: x + w - 1, y1: y + h - 1, 0)
        for xx in (x + 1)..<(x + w - 1) {
            set(xx, y, 3)
            set(xx, y + h - 1, 3)
        }
        for yy in (y + 1)..<(y + h - 1) {
            set(x, yy, 3)
            set(x + w - 1, yy, 3)
        }
        let tx = x + 5
        let by = y + h - 1
        set(tx - 1, by, 0)
        set(tx - 2, by, 0)
        set(tx, by, 3)
        set(tx - 2, by + 1, 3)
        set(tx - 3, by + 2, 3)
        var cx = x + 4
        for i in runes {
            let glyph = PetSprites.runes[i % PetSprites.runes.count]
            stamp(glyph, x: cx, y: y + 3)
            cx += glyph.width + 2
        }
    }
}

// MARK: - Сцена

/// Башня, когда сыт; темница, когда голодает.
enum PetScene {
    static let width = 96
    static let height = 60
    /// Длина анимации «пьёт зелье», в тиках по 0,5 с
    static let eatingFrames = 10
    /// Длина реакции на касание
    static let reactionFrames = 6

    /// Маг в профиль и кафедра с книгой (башня)
    private static let mageX = 30
    private static let mageY = 13
    private static let lecternX = 52
    private static let lecternY = 22

    private static func candles(_ buf: inout PixelBuffer, lit: Int, tick: Int) {
        for i in 0..<4 {
            let sprite: PetSprite
            if i < lit {
                sprite = (i + tick) % 2 == 0 ? PetSprites.candleLitA : PetSprites.candleLitB
            } else {
                sprite = PetSprites.candleOut
            }
            buf.stamp(sprite, x: 5 + i * 7, y: 1)
        }
    }

    /// Звёзды в окне башни мерцают.
    private static func stars(_ buf: inout PixelBuffer, tick: Int) {
        let list = [(62, 13), (66, 22), (63, 30), (78, 29), (73, 33), (61, 20)]
        for (i, p) in list.enumerated() {
            buf.set(p.0, p.1, (tick + i) % 5 == 0 ? 3 : 2)
        }
    }

    /// Над раскрытой книгой поднимаются светящиеся руны.
    private static func bookGlow(_ buf: inout PixelBuffer, tick: Int, burst: Bool) {
        buf.stamp(tick % 2 == 0 ? PetSprites.glowA : PetSprites.glowB, x: lecternX + 3, y: lecternY - 1 - (tick % 3))
        if burst {
            buf.stamp(tick % 2 == 0 ? PetSprites.glowB : PetSprites.glowA, x: lecternX + 2, y: lecternY - 6)
            buf.stamp(PetSprites.glowA, x: lecternX + 4, y: lecternY - 11 + (tick % 2))
        }
    }

    /// Башня: фон, звёзды, свечи и кафедра с книгой.
    private static func towerBase(_ buf: inout PixelBuffer, lit: Int, tick: Int, pageTurn: Bool) {
        buf.stamp(PetSprites.tower, x: 0, y: 0)
        stars(&buf, tick: tick)
        candles(&buf, lit: lit, tick: tick)
        buf.stamp(PetSprites.lectern, x: lecternX, y: lecternY)
        if pageTurn {
            buf.stamp(PetSprites.pageTurn, x: lecternX + 2, y: lecternY - 1)
        }
    }

    /// Машет рукой, над головой сердечко (реакция на касание в башне).
    private static func wave(_ buf: inout PixelBuffer, frame: Int) {
        buf.stamp(PetSprites.mageSideWave, x: mageX, y: mageY - (frame % 2))
        buf.stamp(PetSprites.heart, x: mageX + 21, y: mageY - 6 - frame * 2)
    }

    /// Капля с потолка темницы.
    private static func drip(_ buf: inout PixelBuffer, tick: Int, x: Int) {
        let t = tick % 10
        if t < 8 {
            buf.stamp(PetSprites.drop, x: x, y: 15 + t * 4)
        } else {
            buf.stamp(PetSprites.splash, x: x - 1, y: 47)
        }
    }

    /// Кадр экрана.
    /// - tick: номер тика (каждые 0,5 с)
    /// - eatingFrame: кадр анимации «пьёт зелье» или nil
    /// - reactionFrame: кадр реакции на касание или nil
    static func compose(mood: PetMood, food: Double, tick: Int,
                        eatingFrame: Int? = nil, reactionFrame: Int? = nil) -> PixelBuffer {
        var buf = PixelBuffer(width: width, height: height)
        let lit = PetRules.hearts(food: food)

        // Касание: короткая тряска экрана
        let shake = reactionFrame.map { $0 < 2 ? ($0 % 2 == 0 ? 1 : -1) : 0 } ?? 0

        if let f = eatingFrame {
            towerBase(&buf, lit: lit, tick: tick, pageTurn: false)
            if f < 6 {
                // пьёт из склянки, пузырьки поднимаются
                buf.stamp(PetSprites.mageSideDrink, x: mageX, y: mageY + (f % 2 == 0 ? 0 : -1))
                buf.set(mageX + 18 + (f % 2), mageY + 7 - (f % 3), 3)
                buf.set(mageX + 20 - (f % 2), mageY + 4 - (f % 3), 2)
            } else {
                wave(&buf, frame: f - 6)
                bookGlow(&buf, tick: tick, burst: true)
            }
            return buf
        }

        switch mood {
        case .happy:
            // читает книгу за кафедрой, время от времени перелистывает
            let turning = tick % 8 == 7
            towerBase(&buf, lit: lit, tick: tick, pageTurn: turning)
            if let r = reactionFrame {
                wave(&buf, frame: r)
                bookGlow(&buf, tick: tick, burst: true)
            } else {
                buf.stamp(turning ? PetSprites.mageSideRead2 : PetSprites.mageSideRead, x: mageX, y: mageY)
                bookGlow(&buf, tick: tick, burst: false)
            }

        case .ok:
            // проголодался: книга заброшена, думает о зелье
            towerBase(&buf, lit: lit, tick: tick, pageTurn: false)
            if let r = reactionFrame {
                wave(&buf, frame: r)
            } else {
                buf.stamp(PetSprites.mageSideTired, x: mageX, y: mageY)
            }
            if reactionFrame != nil || tick % 6 < 4 {
                buf.stamp(PetSprites.thoughtPotion, x: mageX + 12, y: mageY - 13 + (tick % 2))
            }

        case .angry:
            buf.stamp(PetSprites.dungeon, x: 0, y: 0)
            candles(&buf, lit: lit, tick: tick)
            drip(&buf, tick: tick, x: 70)
            buf.stamp(tick % 2 == 0 ? PetSprites.mageAngry : PetSprites.mageAngry2, x: 20 + shake, y: 10)
            if reactionFrame != nil {
                buf.runeBubble([9, 9, 9, 9], x: 46, y: 16)
            } else if tick % 6 < 4 {
                let phrase = PetRules.curses[(tick / 6) % PetRules.curses.count]
                buf.runeBubble(phrase, x: 46, y: 16)
            }

        case .skeleton:
            buf.stamp(PetSprites.dungeonChained, x: 0, y: 0)
            candles(&buf, lit: lit, tick: tick)
            drip(&buf, tick: tick, x: 70)
            // касание: кости гремят, крыса удирает
            let rattle = reactionFrame.map { $0 % 2 == 0 ? -2 : 0 } ?? 0
            buf.stamp((tick / 2) % 2 == 0 || reactionFrame != nil ? PetSprites.skeleton1 : PetSprites.skeleton2,
                      x: 18 + shake, y: 24 + rattle)
            // крыса пробегает по полу справа налево
            let ratX = reactionFrame.map { 60 - $0 * 18 } ?? (100 - (tick * 3) % 150)
            buf.stamp(tick % 2 == 0 ? PetSprites.ratA : PetSprites.ratB, x: ratX, y: 53)
            if reactionFrame != nil || tick % 12 >= 9 {
                buf.runeBubble([10], x: 48, y: 20)
            }
        }
        return buf
    }
}
