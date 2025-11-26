import SwiftUI

struct EmojiPickerView: View {
    @Environment(\.dismiss) private var dismiss
    var onSelect: (String) -> Void

    private static func makeEmojis() -> [String] {
        let faces = "😀 😃 😄 😁 😆 🥳 🤩 🙂 😉 😊 😇 😍 🥰 😘 😎 😏 🤔 🤗 😴 🥱 🤤 🤒 🤕".split(separator: " ").map(String.init)
        let monsters = "🤑 🤡 👻 👽 🤖 🎃".split(separator: " ").map(String.init)
        let animals = "🐶 🐱 🐻 🐼 🐨 🐯 🦁 🐷 🐸 🐵 🦄 🐥 🐣 🐔 🐧 🐦 🦆 🦅 🦉 🦇 🐺".split(separator: " ").map(String.init)
        let hearts = "❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❣️ 💕 💞 💓 💗 💖 💘 💝 💟".split(separator: " ").map(String.init)
        let nature = "⭐️ 🌟 ✨ 🔥 💧 🌈 ☀️ ☁️ 🌤️ ⛅️ 🌥️ 🌦️ 🌧️ 🌨️ 🌪️ 🌊 🌙 🌍 🌎 🌏".split(separator: " ").map(String.init)
        let office = "📚 📝 ✏️ 🖊️ 🖋️ 🖍️ 🗂️ 📁 📂 🗃️ 🗄️ 🗳️ 📦 📌 📍 ✂️ 📏 📐 🧷 🧵 🧶".split(separator: " ").map(String.init)
        let tools = "🛠️ 🔧 🔨 ⚙️ 🧰 🪛 🪚 🪜".split(separator: " ").map(String.init)
        let travel = "🚀 ✈️ 🚗 🚕 🚌 🚎 🏎️ 🚓 🚑 🚒 🚲 🛴 🏍️ 🛵 🛶 ⛵️ 🛳️ 🚢".split(separator: " ").map(String.init)
        let food = "🍎 🍊 🍋 🍌 🍉 🍇 🍓 🫐 🍒 🍑 🥭 🍍 🥝 🥑 🍅 🥕 🌽 🥔".split(separator: " ").map(String.init)
        let sports = "⚽️ 🏀 🏈 ⚾️ 🎾 🏐 🏉 🥏 🎱 🏓 🏸 🥅 ⛳️ 🏹 🎣 🎿 ⛷️ 🏂".split(separator: " ").map(String.init)
        let music = "🎵 🎶 🎼 🎤 🎧 🎷 🎸 🎹 🎺 🥁 🪘".split(separator: " ").map(String.init)
        let misc = "🔒 🔑 🗝️ 📣 📢 🔔 🔕 🏠 🏡 🏢 🏫 🏬 🏭 🏗️ 🏛️ ⛪️ 🕌 🛕 🏯 🏰".split(separator: " ").map(String.init)
        return faces + monsters + animals + hearts + nature + office + tools + travel + food + sports + music + misc
    }

    private let emojis: [String] = EmojiPickerView.makeEmojis()
    private let columns = [GridItem(.adaptive(minimum: 44))]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button {
                            onSelect(emoji)
                            dismiss()
                        } label: {
                            Text(emoji)
                                .font(.system(size: 28))
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Emoji")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
