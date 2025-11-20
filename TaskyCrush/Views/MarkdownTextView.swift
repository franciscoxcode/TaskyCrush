import SwiftUI
import UIKit

final class MarkdownEditorController: ObservableObject {
    weak var textView: UITextView?
    // Stage 3: sticky typing modes
    enum Mode: Hashable { case bold, italic, strike }
    private var anchors: [Mode: Int] = [:]
    private(set) var activeModes: Set<Mode> = []
    var showTokens: Bool = true
    private(set) var didDoInitialStyle: Bool = false

    // Cache regex to avoid recompilation on every keystroke
    private static let reBold = try! NSRegularExpression(pattern: #"\*\*(.+?)\*\*"#, options: [])
    private static let reStrike = try! NSRegularExpression(pattern: #"~~(.+?)~~"#, options: [])
    // single-asterisk italics, avoiding **
    private static let reItalic = try! NSRegularExpression(pattern: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, options: [])
    private static let reChecklist = try! NSRegularExpression(pattern: #"(?m)^- \[ (?:\]|x)\]\s"#, options: [])

    @MainActor func wrapSelection(with token: String) {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        let ns = tv.text as NSString? ?? "" as NSString
        let selected = ns.substring(with: range)
        let newText = token + selected + token
        tv.replaceSelectedText(with: newText)
        // If empty selection, place caret between tokens; else after wrapped text
        let newLocation: Int
        if range.length == 0 {
            newLocation = range.location + token.count
        } else {
            newLocation = range.location + newText.count
        }
        tv.selectedRange = NSRange(location: newLocation, length: 0)
        sendEditingChanged()
    }

    @MainActor func insertPrefixAtLineStart(_ prefix: String) {
        guard let tv = textView else { return }
        let r = tv.selectedRange
        guard let lineRange = tv.currentLineRange() else { return }
        let ns = tv.text as NSString? ?? "" as NSString
        let lineText = ns.substring(with: lineRange)
        let newLine = prefix + lineText
        tv.replaceText(in: lineRange, with: newLine)
        // Keep cursor relative position shifted by prefix length if inside the line
        if r.location >= lineRange.location && r.location <= lineRange.location + lineRange.length {
            let delta = prefix.count
            tv.selectedRange = NSRange(location: r.location + delta, length: r.length)
        }
        sendEditingChanged()
    }

    @MainActor func insertPrefixForSelectedLines(_ prefix: String) {
        guard let tv = textView else { return }
        guard let block = tv.selectedLinesRange() else { return }
        let ns = tv.text as NSString? ?? "" as NSString
        let blockText = ns.substring(with: block)
        let lines = blockText.split(separator: "\n", omittingEmptySubsequences: false)
        let transformed = lines.map { prefix + $0 }
        let newBlock = transformed.joined(separator: "\n")
        tv.replaceText(in: block, with: newBlock)
        // Adjust selection: expand by prefix length per line before the caret
        let selection = tv.selectedRange
        let added = addedPrefixForSelection(prefix: prefix, originalBlock: blockText, selection: selection, blockRange: block)
        tv.selectedRange = NSRange(location: selection.location + added, length: selection.length)
        sendEditingChanged()
    }

    @MainActor func toggleChecklist() {
        guard let tv = textView else { return }
        guard let block = tv.selectedLinesRange() else { return }
        let ns = tv.text as NSString? ?? "" as NSString
        let blockText = ns.substring(with: block)
        let lines = blockText.split(separator: "\n", omittingEmptySubsequences: false)
        let toggled = lines.map { line -> String in
            let s = String(line)
            if s.hasPrefix("- [ ] ") { return String(s.dropFirst(6)) }
            else { return "- [ ] " + s }
        }
        let newBlock = toggled.joined(separator: "\n")
        tv.replaceText(in: block, with: newBlock)
        sendEditingChanged()
    }

    @MainActor func heading(_ level: Int) {
        guard let tv = textView else { return }
        guard let line = tv.currentLineRange() else { return }
        let ns = tv.text as NSString? ?? "" as NSString
        let current = ns.substring(with: line)
        let desired = String(repeating: "#", count: max(1, min(level, 6))) + " "
        // Remove any existing leading #'s and space
        let trimmed = current.replacingOccurrences(of: "^#{1,6} ", with: "", options: .regularExpression)
        let newLine: String
        if current.hasPrefix(desired) {
            // Toggle off (remove the heading prefix)
            newLine = trimmed
        } else {
            newLine = desired + trimmed
        }
        tv.replaceText(in: line, with: newLine)
        // Adjust caret: move to start of content (after heading if applied)
        let caretBase = line.location + (newLine.hasPrefix(desired) ? desired.count : 0)
        tv.selectedRange = NSRange(location: caretBase, length: 0)
        sendEditingChanged()
    }

    // MARK: - Sticky typing modes
    @MainActor func toggleMode(_ mode: Mode) {
        guard let tv = textView else { return }
        if activeModes.contains(mode) {
            // Deactivate: wrap from anchor to caret
            let caret = tv.selectedRange.location
            if let start = anchors[mode], caret > start {
                let wrapRange = NSRange(location: start, length: caret - start)
                tv.selectedRange = wrapRange
                wrapSelection(with: token(for: mode))
            }
            anchors[mode] = nil
            activeModes.remove(mode)
            updateTypingAttributes()
        } else {
            anchors[mode] = tv.selectedRange.location
            activeModes.insert(mode)
            updateTypingAttributes()
        }
    }

    private func token(for mode: Mode) -> String {
        switch mode { case .bold: return "**"; case .italic: return "*"; case .strike: return "~~" }
    }

    private func updateTypingAttributes() {
        guard let tv = textView else { return }
        var font = UIFont.preferredFont(forTextStyle: .body)
        var traits: UIFontDescriptor.SymbolicTraits = []
        if activeModes.contains(.bold) { traits.insert(.traitBold) }
        if activeModes.contains(.italic) { traits.insert(.traitItalic) }
        if !traits.isEmpty, let desc = font.fontDescriptor.withSymbolicTraits(traits) {
            font = UIFont(descriptor: desc, size: font.pointSize)
        }
        var attrs: [NSAttributedString.Key: Any] = [.font: font]
        if activeModes.contains(.strike) {
            attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        tv.typingAttributes = attrs
    }

    // MARK: - Live styling (syntax highlight + sticky overlays)
    // Public entrypoint used while typing/selection changes
    func refreshPresentation() {
        refresh(scope: .visible)
    }

    // Initial full pass (first mount or when tokens mode changed)
    func refreshPresentationFull() {
        refresh(scope: .full)
        didDoInitialStyle = true
    }

    private enum RefreshScope { case full, visible }

    private func refresh(scope: RefreshScope) {
        guard let tv = textView else { return }
        let storage = tv.textStorage
        let ns = storage.string as NSString

        // Determine target character range
        let target: NSRange
        switch scope {
        case .full:
            target = NSRange(location: 0, length: ns.length)
        case .visible:
            target = visibleCharacterRange(in: tv, nsLength: ns.length)
        }

        storage.beginEditing()
        applyBaseAttributes(storage, in: target)
        applyHeadingAttributes(storage, in: target)
        applyInlineAttributes(storage, in: target)
        storage.endEditing()
        applyActiveModeVisuals()
    }

    private func visibleCharacterRange(in tv: UITextView, nsLength: Int) -> NSRange {
        let layout = tv.layoutManager
        let container = tv.textContainer
        // Compute visible rect in text container coordinates
        var visible = tv.bounds
        visible.origin = tv.contentOffset
        visible = visible.insetBy(dx: tv.textContainerInset.left, dy: tv.textContainerInset.top)
        let glyphs = layout.glyphRange(forBoundingRect: visible, in: container)
        var chars = layout.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
        // Expand a bit above/below to reduce edge artifacts
        let pad = 600
        let loc = max(0, chars.location - pad)
        let end = min(nsLength, chars.location + chars.length + pad)
        chars = NSRange(location: loc, length: end - loc)
        return chars
    }

    private func applyBaseAttributes(_ storage: NSTextStorage, in range: NSRange) {
        storage.removeAttribute(.font, range: range)
        storage.removeAttribute(.foregroundColor, range: range)
        storage.removeAttribute(.strikethroughStyle, range: range)
        storage.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .body), range: range)
        storage.addAttribute(.foregroundColor, value: UIColor.label, range: range)
    }

    private func applyHeadingAttributes(_ storage: NSTextStorage, in target: NSRange) {
        let ns = storage.string as NSString
        var idx = target.location
        let limit = min(ns.length, target.location + target.length)
        while idx < limit {
            let lineRange = ns.lineRange(for: NSRange(location: idx, length: 0))
            if lineRange.length == 0 { break }
            let line = ns.substring(with: lineRange)
            if let match = try? NSRegularExpression(pattern: "^(#{1,6})\\s").firstMatch(in: line, options: [], range: NSRange(location: 0, length: (line as NSString).length)) {
                let hashesRange = match.range(at: 1)
                let tokenRange = NSRange(location: lineRange.location + hashesRange.location, length: hashesRange.length + 1) // include space
                let contentRange = NSRange(location: lineRange.location + hashesRange.length + 1, length: lineRange.length - (hashesRange.length + 1))
                // Dim or hide tokens (zero-size font removes spacing)
                let tokenColor = showTokens ? UIColor.secondaryLabel : UIColor.clear
                storage.addAttribute(.foregroundColor, value: tokenColor, range: tokenRange)
                if !showTokens {
                    let tiny = UIFont.systemFont(ofSize: 0.1)
                    storage.addAttribute(.font, value: tiny, range: tokenRange)
                }
                // Larger font for content according to level
                let level = hashesRange.length
                let font: UIFont
                switch level {
                case 1: font = UIFont.preferredFont(forTextStyle: .title2)
                case 2: font = UIFont.preferredFont(forTextStyle: .headline)
                case 3: font = UIFont.preferredFont(forTextStyle: .subheadline)
                default: font = UIFont.preferredFont(forTextStyle: .body)
                }
                storage.addAttribute(.font, value: font, range: contentRange)
            }
            idx = lineRange.location + lineRange.length
        }
    }

    private func applyInlineAttributes(_ storage: NSTextStorage, in range: NSRange) {
        func applyRegex(_ re: NSRegularExpression, tokenLen: Int, applyContent: (NSRange) -> Void) {
            re.enumerateMatches(in: storage.string, options: [], range: range) { match, _, _ in
                guard let m = match else { return }
                let mr = m.range
                if mr.length < tokenLen * 2 { return }
                let content = NSRange(location: mr.location + tokenLen, length: mr.length - tokenLen * 2)
                let tokenColor = showTokens ? UIColor.secondaryLabel : UIColor.clear
                let leading = NSRange(location: mr.location, length: tokenLen)
                let trailing = NSRange(location: mr.location + mr.length - tokenLen, length: tokenLen)
                storage.addAttribute(.foregroundColor, value: tokenColor, range: leading)
                storage.addAttribute(.foregroundColor, value: tokenColor, range: trailing)
                if !showTokens {
                    let tiny = UIFont.systemFont(ofSize: 0.1)
                    storage.addAttribute(.font, value: tiny, range: leading)
                    storage.addAttribute(.font, value: tiny, range: trailing)
                }
                applyContent(content)
            }
        }
        // Bold: **text**
        applyRegex(Self.reBold, tokenLen: 2) { content in
            if let desc = UIFont.preferredFont(forTextStyle: .body).fontDescriptor.withSymbolicTraits(.traitBold) {
                let f = UIFont(descriptor: desc, size: UIFont.preferredFont(forTextStyle: .body).pointSize)
                storage.addAttribute(.font, value: f, range: content)
            }
        }
        // Strike: ~~text~~
        applyRegex(Self.reStrike, tokenLen: 2) { content in
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: content)
        }
        // Italic: single *text* (avoid **)
        applyRegex(Self.reItalic, tokenLen: 1) { content in
            if let desc = UIFont.preferredFont(forTextStyle: .body).fontDescriptor.withSymbolicTraits(.traitItalic) {
                let f = UIFont(descriptor: desc, size: UIFont.preferredFont(forTextStyle: .body).pointSize)
                storage.addAttribute(.font, value: f, range: content)
            }
        }
        // Checklist tokens: dim '- [ ] '
        Self.reChecklist.enumerateMatches(in: storage.string, options: [], range: range) { match, _, _ in
            if let r = match?.range {
                let tokenColor = showTokens ? UIColor.secondaryLabel : UIColor.clear
                storage.addAttribute(.foregroundColor, value: tokenColor, range: r)
                if !showTokens {
                    let tiny = UIFont.systemFont(ofSize: 0.1)
                    storage.addAttribute(.font, value: tiny, range: r)
                }
            }
        }
    }

    func applyActiveModeVisuals() {
        guard let tv = textView else { return }
        let caret = tv.selectedRange.location
        let storage = tv.textStorage
        for mode in activeModes {
            guard let start = anchors[mode], caret >= start else { continue }
            let range = NSRange(location: start, length: caret - start)
            var f = UIFont.preferredFont(forTextStyle: .body)
            var traits: UIFontDescriptor.SymbolicTraits = []
            if mode == .bold { traits.insert(.traitBold) }
            if mode == .italic { traits.insert(.traitItalic) }
            if !traits.isEmpty, let desc = f.fontDescriptor.withSymbolicTraits(traits) {
                f = UIFont(descriptor: desc, size: f.pointSize)
            }
            storage.addAttribute(.font, value: f, range: range)
            if mode == .strike {
                storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
        }
    }

    // MARK: - Toggle checkbox state by tap
    @MainActor func toggleCheckbox(atCharacter offset: Int) {
        guard let tv = textView else { return }
        let ns = tv.text as NSString? ?? "" as NSString
        let lineRange = ns.lineRange(for: NSRange(location: min(offset, ns.length), length: 0))
        if lineRange.length == 0 { return }
        let line = ns.substring(with: lineRange)
        let prefixUnchecked = "- [ ] "
        let prefixChecked = "- [x] "
        let newLine: String
        if line.hasPrefix(prefixUnchecked) {
            newLine = prefixChecked + String(line.dropFirst(prefixUnchecked.count))
        } else if line.hasPrefix(prefixChecked) {
            newLine = prefixUnchecked + String(line.dropFirst(prefixChecked.count))
        } else {
            return
        }
        tv.replaceText(in: lineRange, with: newLine)
        sendEditingChanged()
    }

    // MARK: - Extra actions: quote, code, link
    @MainActor func toggleBlockQuote() {
        guard let tv = textView else { return }
        guard let block = tv.selectedLinesRange() else { return }
        let ns = tv.text as NSString? ?? "" as NSString
        let blockText = ns.substring(with: block)
        let lines = blockText.split(separator: "\n", omittingEmptySubsequences: false)
        let toggled = lines.map { s -> String in
            let t = String(s)
            if t.hasPrefix("> ") { return String(t.dropFirst(2)) }
            return "> " + t
        }
        let newBlock = toggled.joined(separator: "\n")
        tv.replaceText(in: block, with: newBlock)
        sendEditingChanged()
    }

    @MainActor func wrapInlineCode() { wrapSelection(with: "`") }

    @MainActor func wrapLink() {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        let ns = tv.text as NSString? ?? "" as NSString
        let selected = ns.substring(with: range)
        let linkText: String
        let linkURL: String
        if selected.range(of: "^https?://\\S+$", options: .regularExpression) != nil {
            linkText = selected
            linkURL = selected
        } else if !selected.isEmpty {
            linkText = selected
            linkURL = "https://"
        } else {
            linkText = "link"
            linkURL = "https://"
        }
        let insertion = "[" + linkText + "](" + linkURL + ")"
        tv.replaceSelectedText(with: insertion)
        // place caret inside URL if inserted empty url
        if linkURL == "https://" {
            let start = range.location + linkText.count + 3 // [text](
            tv.selectedRange = NSRange(location: start, length: linkURL.count)
        } else {
            tv.selectedRange = NSRange(location: range.location + insertion.count, length: 0)
        }
        sendEditingChanged()
    }

    // MARK: - Ordered list toggle
    @MainActor func toggleOrderedList() {
        guard let tv = textView else { return }
        guard let block = tv.selectedLinesRange() else { return }
        let ns = tv.text as NSString? ?? "" as NSString
        let blockText = ns.substring(with: block)
        let lines = blockText.split(separator: "\n", omittingEmptySubsequences: false)
        let allNumbered = lines.allSatisfy { $0.firstMatch(of: /^\d+\.\s/) != nil }
        if allNumbered {
            // Remove numbers
            let stripped = lines.map { line -> String in
                let s = String(line)
                if let m = try? NSRegularExpression(pattern: "^\\d+\\. "), let match = m.firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length)) {
                    let r = match.range
                    if let rr = Range(r, in: s) { return String(s[rr.upperBound...]) }
                }
                return s
            }
            tv.replaceText(in: block, with: stripped.joined(separator: "\n"))
        } else {
            // Add sequential numbers starting at 1
            var i = 1
            let numbered = lines.map { line -> String in
                defer { i += 1 }
                return "\(i). " + line
            }
            tv.replaceText(in: block, with: numbered.joined(separator: "\n"))
        }
        sendEditingChanged()
    }


    private func addedPrefixForSelection(prefix: String, originalBlock: String, selection: NSRange, blockRange: NSRange) -> Int {
        // Rough heuristic: add prefix length if cursor not at very start of block
        // and there is at least one newline before selection.
        let local = selection.location - blockRange.location
        if local <= 0 { return 0 }
        // Count number of lines before caret
        let head = String(originalBlock.prefix(local))
        let linesBefore = head.reduce(0) { $1 == "\n" ? $0 + 1 : $0 }
        return linesBefore * prefix.count
    }

    @MainActor private func sendEditingChanged() {
        // Manually notify bound text update
        textView?.delegate?.textViewDidChange?(textView!)
    }
}

private extension UITextView {
    func replaceSelectedText(with newText: String) {
        if let range = Range(selectedRange, in: text) {
            text.replaceSubrange(range, with: newText)
        }
    }

    func replaceText(in nsRange: NSRange, with newText: String) {
        if let range = Range(nsRange, in: text) {
            text.replaceSubrange(range, with: newText)
        }
    }

    func currentLineRange() -> NSRange? {
        let ns = text as NSString
        let caret = selectedRange.location
        let start = ns.range(of: "\n", options: .backwards, range: NSRange(location: 0, length: min(caret, ns.length))).location
        let lineStart = (start == NSNotFound) ? 0 : start + 1
        let endSearchRange = NSRange(location: caret, length: ns.length - caret)
        let end = ns.range(of: "\n", options: [], range: endSearchRange).location
        let lineEnd = (end == NSNotFound) ? ns.length : end
        return NSRange(location: lineStart, length: max(0, lineEnd - lineStart))
    }

    func selectedLinesRange() -> NSRange? {
        let ns = text as NSString
        let sel = selectedRange
        let start = ns.range(of: "\n", options: .backwards, range: NSRange(location: 0, length: min(sel.location, ns.length))).location
        let lineStart = (start == NSNotFound) ? 0 : start + 1
        let endSearchLoc = min(sel.location + sel.length, ns.length)
        let endSearchRange = NSRange(location: endSearchLoc, length: ns.length - endSearchLoc)
        let end = ns.range(of: "\n", options: [], range: endSearchRange).location
        let lineEnd = (end == NSNotFound) ? ns.length : end
        return NSRange(location: lineStart, length: max(0, lineEnd - lineStart))
    }
}

@MainActor
struct MarkdownTextView: UIViewRepresentable {
    @Binding var text: String
    var controller: MarkdownEditorController

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.font = .preferredFont(forTextStyle: .body)
        tv.autocorrectionType = .yes
        tv.autocapitalizationType = .sentences
        tv.smartDashesType = .yes
        tv.smartQuotesType = .yes
        tv.isScrollEnabled = true
        tv.isEditable = true
        tv.isSelectable = true
        tv.text = text
        controller.textView = tv
        tv.layoutManager.allowsNonContiguousLayout = true
        // Attach a custom accessory bar above the keyboard
        tv.inputAccessoryView = makeAccessoryBar()
        // Initial presentation styling
        if !controller.didDoInitialStyle { controller.refreshPresentationFull() }
        // Tap to toggle checkbox state
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        tv.addGestureRecognizer(tap)
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        if controller.textView !== uiView {
            controller.textView = uiView
        }
        // Ensure accessory bar remains attached
        if uiView.inputAccessoryView == nil {
            uiView.inputAccessoryView = makeAccessoryBar()
        }
        // Only restyle fully on first mount; incremental styling occurs on changes
        if !controller.didDoInitialStyle { controller.refreshPresentationFull() }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text, controller: controller) }

    private func makeAccessoryBar() -> UIView {
        let container = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        // inputAccessoryView uses its frame for height
        container.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 46)
        container.autoresizingMask = [.flexibleWidth]

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.contentView.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: container.contentView.leadingAnchor, constant: 8),
            scroll.trailingAnchor.constraint(equalTo: container.contentView.trailingAnchor, constant: -8),
            scroll.topAnchor.constraint(equalTo: container.contentView.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.contentView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])

        func makeButton(_ title: String?, _ systemName: String?) -> UIButton {
            var cfg = UIButton.Configuration.tinted()
            cfg.cornerStyle = .capsule
            cfg.background.backgroundColor = UIColor.secondarySystemFill
            cfg.baseForegroundColor = UIColor.label
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
            cfg.imagePadding = 6
            if let title = title { cfg.title = title }
            if let name = systemName { cfg.image = UIImage(systemName: name) }
            let btn = UIButton(configuration: cfg)
            btn.translatesAutoresizingMaskIntoConstraints = false
            return btn
        }

        let h1 = makeButton("H1", nil)
        let h2 = makeButton("H2", nil)
        let bold = makeButton(nil, "bold")
        let italic = makeButton(nil, "italic")
        let strike = makeButton(nil, "strikethrough")
        let checklist = makeButton(nil, "checklist")
        let bullet = makeButton(nil, "list.bullet")
        let ordered = makeButton(nil, "list.number")
        let quote = makeButton(nil, "text.quote")
        let code = makeButton("`code`", nil)
        let link = makeButton(nil, "link")

        [h1, h2, bold, italic, strike, checklist, bullet, ordered, quote, code, link].forEach { stack.addArrangedSubview($0) }

        // Color accents per group
        func setBaseColor(_ btn: UIButton, _ color: UIColor) {
            var cfg = btn.configuration
            cfg?.background.backgroundColor = color.withAlphaComponent(0.18)
            cfg?.baseForegroundColor = UIColor.label
            btn.configuration = cfg
        }
        setBaseColor(h1, .systemTeal); setBaseColor(h2, .systemTeal)
        setBaseColor(bold, .systemBlue); setBaseColor(italic, .systemBlue); setBaseColor(strike, .systemBlue)
        setBaseColor(checklist, .systemGreen); setBaseColor(bullet, .systemGreen); setBaseColor(ordered, .systemGreen)
        setBaseColor(quote, .systemGray); setBaseColor(code, .systemOrange); setBaseColor(link, .systemPurple)

        func setSelected(_ btn: UIButton, _ on: Bool) {
            guard var cfg = btn.configuration else { return }
            cfg.cornerStyle = .capsule
            cfg.background.backgroundColor = on ? UIColor.systemBlue.withAlphaComponent(0.25) : UIColor.secondarySystemFill
            btn.configuration = cfg
            btn.isSelected = on
        }
        func updateButtons(_ controller: MarkdownEditorController) {
            let modes = controller.activeModes
            setSelected(bold, modes.contains(.bold))
            setSelected(italic, modes.contains(.italic))
            setSelected(strike, modes.contains(.strike))
        }
        // Wire actions after all buttons exist
        h1.addAction(UIAction { [weak controller] _ in controller?.heading(1) }, for: .primaryActionTriggered)
        h2.addAction(UIAction { [weak controller] _ in controller?.heading(2) }, for: .primaryActionTriggered)
        bold.addAction(UIAction { [weak controller] _ in
            guard let c = controller, let tv = c.textView else { return }
            if tv.selectedRange.length > 0 { c.wrapSelection(with: "**") } else { c.toggleMode(.bold) }
            updateButtons(c)
        }, for: .primaryActionTriggered)
        italic.addAction(UIAction { [weak controller] _ in
            guard let c = controller, let tv = c.textView else { return }
            if tv.selectedRange.length > 0 { c.wrapSelection(with: "*") } else { c.toggleMode(.italic) }
            updateButtons(c)
        }, for: .primaryActionTriggered)
        strike.addAction(UIAction { [weak controller] _ in
            guard let c = controller, let tv = c.textView else { return }
            if tv.selectedRange.length > 0 { c.wrapSelection(with: "~~") } else { c.toggleMode(.strike) }
            updateButtons(c)
        }, for: .primaryActionTriggered)
        checklist.addAction(UIAction { [weak controller] _ in controller?.toggleChecklist() }, for: .primaryActionTriggered)
        bullet.addAction(UIAction { [weak controller] _ in controller?.insertPrefixForSelectedLines("- ") }, for: .primaryActionTriggered)
        ordered.addAction(UIAction { [weak controller] _ in controller?.toggleOrderedList() }, for: .primaryActionTriggered)
        quote.addAction(UIAction { [weak controller] _ in controller?.toggleBlockQuote() }, for: .primaryActionTriggered)
        code.addAction(UIAction { [weak controller] _ in controller?.wrapInlineCode() }, for: .primaryActionTriggered)
        link.addAction(UIAction { [weak controller] _ in controller?.wrapLink() }, for: .primaryActionTriggered)
        // initial sync visual state
        updateButtons(controller)
        return container
    }

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var text: Binding<String>
        weak var controller: MarkdownEditorController?
        private var didKickstartScroll = false
        init(text: Binding<String>, controller: MarkdownEditorController) { self.text = text; self.controller = controller }

        func textViewDidChange(_ textView: UITextView) {
            if text.wrappedValue != textView.text {
                text.wrappedValue = textView.text
            }
            controller?.refreshPresentation()
        }
        func textViewDidChangeSelection(_ textView: UITextView) {
            controller?.applyActiveModeVisuals()
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            // Kickstart layout/scroll so long notes can scroll before first keystroke.
            // Do this once to avoid jitter and avoid polluting undo stack.
            guard !didKickstartScroll else { return }
            didKickstartScroll = true
            DispatchQueue.main.async {
                let undo = textView.undoManager
                undo?.disableUndoRegistration()
                textView.insertText(" ")
                textView.deleteBackward()
                undo?.enableUndoRegistration()
                textView.scrollRangeToVisible(textView.selectedRange)
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let tv = gesture.view as? UITextView else { return }
            let pointInView = gesture.location(in: tv)
            let container = tv.textContainer
            let layout = tv.layoutManager
            var point = pointInView
            point.x -= tv.textContainerInset.left
            point.y -= tv.textContainerInset.top
            let glyphIndex = layout.glyphIndex(for: point, in: container)
            let charIndex = layout.characterIndexForGlyph(at: glyphIndex)
            controller?.toggleCheckbox(atCharacter: charIndex)
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard text == "\n" else { return true }
            guard let c = controller else { return true }
            let ns = textView.text as NSString
            let lineRange = ns.lineRange(for: NSRange(location: min(range.location, ns.length), length: 0))
            let line = ns.substring(with: lineRange)

            // Patterns
            let unchecked = "- [ ] "
            let checked = "- [x] "
            let bullet = "- "
            let numberRegex = try? NSRegularExpression(pattern: "^(\\d+)\\. ")
            var nextPrefix: String? = nil
            var endList = false

            func isEmptyContent(after prefix: String) -> Bool {
                if line.hasPrefix(prefix) {
                    let rest = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                    return rest.isEmpty
                }
                return false
            }

            if line.hasPrefix(unchecked) || line.hasPrefix(checked) {
                if isEmptyContent(after: line.hasPrefix(unchecked) ? unchecked : checked) {
                    endList = true
                } else {
                    nextPrefix = unchecked
                }
            } else if line.hasPrefix(bullet) {
                if isEmptyContent(after: bullet) { endList = true } else { nextPrefix = bullet }
            } else if let re = numberRegex, let m = re.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) {
                let numRange = m.range(at: 1)
                if let rr = Range(numRange, in: line) {
                    let n = Int(line[rr]) ?? 1
                    let content = String(line.dropFirst((line as NSString).range(of: ". ", options: [], range: NSRange(location: 0, length: (line as NSString).length)).upperBound))
                    if content.trimmingCharacters(in: .whitespaces).isEmpty {
                        endList = true
                    } else {
                        nextPrefix = "\(n + 1). "
                    }
                }
            }

            if endList {
                // Replace entire line with just a newline (remove the marker)
                textView.replaceText(in: lineRange, with: "\n")
                textView.selectedRange = NSRange(location: lineRange.location + 1, length: 0)
                c.refreshPresentation()
                return false
            } else if let prefix = nextPrefix {
                textView.replaceSelectedText(with: "\n" + prefix)
                textView.selectedRange = NSRange(location: range.location + 1 + prefix.count, length: 0)
                c.refreshPresentation()
                return false
            }
            return true
        }

        // Only capture taps that hit a checkbox line near the leading edge
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let tv = gestureRecognizer.view as? UITextView else { return false }
            let pointInView = touch.location(in: tv)
            var point = pointInView
            point.x -= tv.textContainerInset.left
            point.y -= tv.textContainerInset.top
            let glyphIndex = tv.layoutManager.glyphIndex(for: point, in: tv.textContainer)
            let charIndex = tv.layoutManager.characterIndexForGlyph(at: glyphIndex)

            let ns = tv.text as NSString
            let lineRange = ns.lineRange(for: NSRange(location: min(charIndex, ns.length), length: 0))
            if lineRange.length == 0 { return false }
            let line = ns.substring(with: lineRange)
            let isCheckbox = line.hasPrefix("- [ ] ") || line.hasPrefix("- [x] ")
            // Leading area threshold (~40pt from content inset)
            let nearLeading = pointInView.x <= (tv.textContainerInset.left + 40)
            return isCheckbox && nearLeading
        }
    }
}
