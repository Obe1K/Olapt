// Сборка на GitHub: swiftc -O OlaPT/Models/TowerMusic.swift Tools/music/main.swift -o dump
// ./dump out.f32 — записывает музыку башни (float32, little-endian) для сверки с Tools/music/tower_music.py.
import Foundation

let started = Date()
let samples = TowerMusic.render()
let ms = Int(Date().timeIntervalSince(started) * 1000)
var data = Data(capacity: samples.count * 4)
for s in samples {
    var le = s.bitPattern.littleEndian
    withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
}
try! data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("Swift: \(samples.count) отсчётов, синтез \(ms) мс (-O, Mac)")
