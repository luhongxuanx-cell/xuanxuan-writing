import SwiftUI
import AppKit
import CryptoKit
import UniformTypeIdentifiers

struct SelectableTextEditor: NSViewRepresentable {
    @Binding var text: String
    var formatRequest: UUID
    var textRequest: UUID
    var proofreadRequest: UUID
    var findReplaceRequest: FindReplaceRequest
    var settings: AppSettings
    var buffer: EditorBuffer
    var onTextChange: () -> Void
    var onStatsChange: (EditorStats) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = true
        scroll.backgroundColor = settings.editorBackgroundNSColor
        scroll.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 150, right: 0)
        guard let textView = scroll.documentView as? NSTextView else {
            return scroll
        }
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: scroll.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.font = settings.editorFont
        textView.insertionPointColor = settings.editorTextNSColor
        textView.drawsBackground = true
        textView.backgroundColor = settings.editorBackgroundNSColor
        textView.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 56, height: 32)
        textView.textContainer?.lineFragmentPadding = 0
        textView.delegate = context.coordinator
        textView.string = text
        applyTextAppearance(textView)
        buffer.text = text
        context.coordinator.textView = textView
        context.coordinator.lastStyleSignature = styleSignature
        context.coordinator.lastLayoutWidth = scroll.contentSize.width
        context.coordinator.reportStats(throttled: false)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        let visibleOrigin = scroll.contentView.bounds.origin
        updateStableLayoutIfNeeded(scroll: scroll, textView: textView, coordinator: context.coordinator)
        if context.coordinator.lastStyleSignature != styleSignature {
            context.coordinator.lastStyleSignature = styleSignature
            applyTextAppearance(textView, preservingSelection: true, preservingScrollIn: scroll)
        }
        if context.coordinator.lastTextRequest != textRequest {
            context.coordinator.lastTextRequest = textRequest
            textView.string = text
            applyTextAppearance(textView, preservingSelection: true, preservingScrollIn: scroll)
            buffer.text = text
            context.coordinator.reportStats(throttled: false)
        } else if textView.string.isEmpty && !text.isEmpty {
            textView.string = text
            applyTextAppearance(textView, preservingSelection: true, preservingScrollIn: scroll)
            buffer.text = text
            context.coordinator.reportStats(throttled: false)
        }
        restoreVisibleOrigin(visibleOrigin, in: scroll)
        if context.coordinator.lastFormatRequest != formatRequest {
            context.coordinator.lastFormatRequest = formatRequest
            context.coordinator.formatSelection()
        }
        if context.coordinator.lastProofreadRequest != proofreadRequest {
            context.coordinator.lastProofreadRequest = proofreadRequest
            context.coordinator.startProofreading()
        }
        if context.coordinator.lastFindReplaceRequest != findReplaceRequest.id {
            context.coordinator.lastFindReplaceRequest = findReplaceRequest.id
            context.coordinator.performFindReplace(findReplaceRequest)
        }
    }

    private func applyTextAppearance(_ textView: NSTextView) {
        applyTextAppearance(textView, preservingSelection: false, preservingScrollIn: nil)
    }

    private func applyTextAppearance(_ textView: NSTextView, preservingSelection: Bool, preservingScrollIn scroll: NSScrollView?) {
        let selectedRange = textView.selectedRange()
        let visibleOrigin = scroll?.contentView.bounds.origin
        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        textView.textColor = settings.editorTextNSColor
        textView.font = settings.editorFont
        textView.typingAttributes = [
            .font: settings.editorFont,
            .foregroundColor: settings.editorTextNSColor
        ]
        if fullRange.length > 0 {
            textView.textStorage?.addAttributes([
                .font: settings.editorFont,
                .foregroundColor: settings.editorTextNSColor
            ], range: fullRange)
        }
        if preservingSelection {
            textView.setSelectedRange(clampedRange(selectedRange, length: fullRange.length))
        }
        if let scroll, let visibleOrigin {
            restoreVisibleOrigin(visibleOrigin, in: scroll)
        }
    }

    private var styleSignature: String {
        "\(settings.themeId)|\(settings.fontName)|\(settings.fontSize)"
    }

    private func updateStableLayoutIfNeeded(scroll: NSScrollView, textView: NSTextView, coordinator: Coordinator) {
        if scroll.backgroundColor != settings.editorBackgroundNSColor {
            scroll.backgroundColor = settings.editorBackgroundNSColor
        }
        if !sameInsets(scroll.contentInsets, editorContentInsets) {
            scroll.contentInsets = editorContentInsets
        }
        if textView.backgroundColor != settings.editorBackgroundNSColor {
            textView.backgroundColor = settings.editorBackgroundNSColor
        }
        textView.insertionPointColor = settings.editorTextNSColor
        textView.textContainer?.widthTracksTextView = true

        let width = scroll.contentSize.width
        if abs(width - coordinator.lastLayoutWidth) > 1 {
            coordinator.lastLayoutWidth = width
            textView.textContainer?.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        }
    }

    private var editorContentInsets: NSEdgeInsets {
        NSEdgeInsets(top: 0, left: 0, bottom: 150, right: 0)
    }

    private func sameInsets(_ lhs: NSEdgeInsets, _ rhs: NSEdgeInsets) -> Bool {
        abs(lhs.top - rhs.top) < 0.5
            && abs(lhs.left - rhs.left) < 0.5
            && abs(lhs.bottom - rhs.bottom) < 0.5
            && abs(lhs.right - rhs.right) < 0.5
    }

    private func restoreVisibleOrigin(_ origin: NSPoint, in scroll: NSScrollView) {
        scroll.contentView.scroll(to: origin)
        scroll.reflectScrolledClipView(scroll.contentView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SelectableTextEditor
        weak var textView: NSTextView?
        var lastFormatRequest: UUID
        var lastTextRequest: UUID
        var lastProofreadRequest: UUID
        var lastFindReplaceRequest: UUID
        var lastStyleSignature = ""
        var lastLayoutWidth: CGFloat = 0
        private var pendingStatsWorkItem: DispatchWorkItem?
        private var lastReportedStats = EditorStats()

        init(_ parent: SelectableTextEditor) {
            self.parent = parent
            self.lastFormatRequest = parent.formatRequest
            self.lastTextRequest = parent.textRequest
            self.lastProofreadRequest = parent.proofreadRequest
            self.lastFindReplaceRequest = parent.findReplaceRequest.id
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            parent.buffer.text = textView.string
            reportStats(throttled: false)
            parent.onTextChange()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            reportStats(throttled: true)
        }

        func reportStats(throttled: Bool) {
            guard let textView else { return }
            pendingStatsWorkItem?.cancel()
            let send = { [weak self, weak textView] in
                guard let self, let textView else { return }
                let stats = editorStats(for: textView.string, selectedRange: textView.selectedRange())
                guard stats != self.lastReportedStats else { return }
                self.lastReportedStats = stats
                self.parent.onStatsChange(stats)
            }
            if throttled {
                let work = DispatchWorkItem(block: send)
                pendingStatsWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: work)
            } else {
                send()
            }
        }

        func formatSelection() {
            guard let textView else { return }
            let nsText = textView.string as NSString
            let selected = textView.selectedRange()
            let range = selected.length > 0 ? selected : NSRange(location: 0, length: nsText.length)
            let source = nsText.substring(with: range)
            let formatted = formatParagraphs(source)
            textView.replaceCharacters(in: range, with: formatted)
            parent.buffer.text = textView.string
            parent.text = textView.string
            parent.onTextChange()
            let cursor = min(range.location + (formatted as NSString).length, (textView.string as NSString).length)
            textView.setSelectedRange(NSRange(location: cursor, length: 0))
            reportStats(throttled: false)
        }

        func startProofreading() {
            guard let textView else { return }
            configureChineseProofreading(for: textView)
            textView.isContinuousSpellCheckingEnabled = true
            textView.checkSpelling(nil)
            NSSpellChecker.shared.spellingPanel.makeKeyAndOrderFront(nil)
        }

        private func configureChineseProofreading(for textView: NSTextView) {
            let checker = NSSpellChecker.shared
            let preferredLanguages = ["zh-Hans", "zh_CN", "zh-Hans_CN", "zh"]
            for language in preferredLanguages {
                if checker.setLanguage(language) {
                    break
                }
            }
            textView.isAutomaticSpellingCorrectionEnabled = false
            textView.isGrammarCheckingEnabled = false
            textView.enabledTextCheckingTypes = NSTextCheckingResult.CheckingType.spelling.rawValue
        }

        func performFindReplace(_ request: FindReplaceRequest) {
            guard let textView else { return }
            guard !request.find.isEmpty else { return }
            switch request.action {
            case .findNext:
                selectMatch(in: textView, request: request, forward: true)
            case .findPrevious:
                selectMatch(in: textView, request: request, forward: false)
            case .replaceCurrent:
                replaceCurrent(in: textView, request: request)
            case .replaceAll:
                replaceMatches(in: textView, request: request, selectionOnly: false)
            case .replaceSelection:
                replaceMatches(in: textView, request: request, selectionOnly: true)
            }
        }

        private func selectMatch(in textView: NSTextView, request: FindReplaceRequest, forward: Bool) {
            let ranges = rangesForFind(request.find, in: textView.string, selectedRange: nil, options: request.options)
            guard !ranges.isEmpty else {
                NSSound.beep()
                return
            }
            let selected = textView.selectedRange()
            let nextRange: NSRange
            if forward {
                nextRange = ranges.first(where: { $0.location > selected.location || ($0.location == selected.location && selected.length == 0) }) ?? ranges[0]
            } else {
                nextRange = ranges.reversed().first(where: { $0.location < selected.location }) ?? ranges[ranges.count - 1]
            }
            textView.setSelectedRange(nextRange)
            textView.scrollRangeToVisible(nextRange)
            textView.window?.makeFirstResponder(textView)
        }

        private func replaceCurrent(in textView: NSTextView, request: FindReplaceRequest) {
            let selected = textView.selectedRange()
            if selected.length > 0, selectedTextMatches(in: textView, range: selected, request: request) {
                textView.replaceCharacters(in: selected, with: request.replacement)
                syncTextViewChange(textView)
                return
            }
            selectMatch(in: textView, request: request, forward: true)
        }

        private func replaceMatches(in textView: NSTextView, request: FindReplaceRequest, selectionOnly: Bool) {
            let selected = textView.selectedRange()
            let selectionRange = selectionOnly ? selected : nil
            let ranges = rangesForFind(request.find, in: textView.string, selectedRange: selectionRange, options: request.options, selectionOnly: selectionOnly)
            guard !ranges.isEmpty else {
                NSSound.beep()
                return
            }
            for range in ranges.reversed() {
                textView.replaceCharacters(in: range, with: request.replacement)
            }
            syncTextViewChange(textView)
            let cursor = min((ranges.first?.location ?? 0) + (request.replacement as NSString).length, (textView.string as NSString).length)
            textView.setSelectedRange(NSRange(location: cursor, length: 0))
            textView.scrollRangeToVisible(NSRange(location: cursor, length: 0))
        }

        private func selectedTextMatches(in textView: NSTextView, range: NSRange, request: FindReplaceRequest) -> Bool {
            let matches = rangesForFind(request.find, in: textView.string, selectedRange: range, options: request.options, selectionOnly: true)
            return matches.count == 1 && matches[0] == range
        }

        private func syncTextViewChange(_ textView: NSTextView) {
            parent.applyTextAppearance(textView)
            parent.buffer.text = textView.string
            parent.text = textView.string
            reportStats(throttled: false)
            parent.onTextChange()
        }
    }
}
