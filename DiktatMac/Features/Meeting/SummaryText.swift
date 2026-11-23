import SwiftUI

/// A summary or live notes on a card: headings stand out, bullet points get a "•", and the
/// Markdown marks a model adds on its own are gone.
struct SummaryText: View {
    let text: String
    /// The title of the card; a first heading saying the same is left out.
    var title: String?
    var size: CGFloat = 12.5

    var body: some View {
        Text(attributed)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var attributed: AttributedString {
        var result = AttributedString()
        let lines = ListDisplay.lines(text, droppingTitle: title)
        for (index, line) in lines.enumerated() {
            var part = AttributedString(line.text + (index < lines.count - 1 ? "\n" : ""))
            part.font = .ui(size, line.isHeading ? .semibold : .regular)
            result += part
        }
        return result
    }
}
