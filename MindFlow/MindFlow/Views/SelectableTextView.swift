//
//  SelectableTextView.swift
//  MindFlow
//
//  Text view with word selection for vocabulary lookup
//

import SwiftUI
import AppKit

/// A text view that allows selecting words to add to vocabulary.
///
/// Supports three modes that can be combined:
/// - Read-only plain text (default)
/// - Editable text via `editableText` (e.g. the optimized/refined field)
/// - Rich rendering via `attributed` (e.g. formatted teacher notes); read-only only
///
/// When `dynamicHeight` is provided the view sizes itself to its content (its own
/// scrolling is disabled) so it can grow inside an outer SwiftUI `ScrollView`.
struct SelectableTextView: NSViewRepresentable {
    let text: String
    var editableText: Binding<String>? = nil
    var attributed: NSAttributedString? = nil
    var dynamicHeight: Binding<CGFloat>? = nil
    let onWordSelected: (String, String) -> Void  // (word, context)

    private var isEditable: Bool { editableText != nil }
    private var isSelfSizing: Bool { dynamicHeight != nil }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = !isSelfSizing
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let textView = VocabularyTextView()
        textView.onWordSelected = onWordSelected
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.usesFontPanel = false
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .labelColor
        textView.delegate = context.coordinator
        textView.allowsUndo = isEditable
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: 2, height: 4)

        // Configure text container
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        applyContent(to: textView)

        scrollView.documentView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        // Refresh the coordinator's view of the latest bindings/closures so it
        // never writes through stale captured state after the bound value changes.
        context.coordinator.parent = self

        guard let textView = scrollView.documentView as? VocabularyTextView else { return }

        textView.onWordSelected = onWordSelected

        if isEditable {
            // Push external changes (e.g. re-optimize) without clobbering edits.
            if let binding = editableText, textView.string != binding.wrappedValue {
                textView.string = binding.wrappedValue
            }
        } else if let attributed = attributed {
            if textView.textStorage?.string != attributed.string {
                textView.textStorage?.setAttributedString(attributed)
            }
        } else if textView.string != text {
            textView.string = text
        }

        if isSelfSizing {
            recalculateHeight(for: textView)
        }
    }

    private func applyContent(to textView: NSTextView) {
        if isEditable {
            textView.string = editableText?.wrappedValue ?? text
        } else if let attributed = attributed {
            textView.textStorage?.setAttributedString(attributed)
        } else {
            textView.string = text
        }
    }

    /// Measure the laid-out text and report its height back to SwiftUI.
    private func recalculateHeight(for textView: NSTextView) {
        guard let binding = dynamicHeight,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return }

        layoutManager.ensureLayout(for: container)
        let used = layoutManager.usedRect(for: container).height
        let height = ceil(used + textView.textContainerInset.height * 2)

        if abs(binding.wrappedValue - height) > 0.5 {
            // Defer to avoid mutating SwiftUI state during a view update.
            DispatchQueue.main.async {
                binding.wrappedValue = height
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        /// Reference back to the current representable so reads always use the
        /// latest bindings/closures rather than values captured at creation.
        var parent: SelectableTextView

        init(_ parent: SelectableTextView) {
            self.parent = parent
        }

        /// Mirror user edits back into the SwiftUI binding when editable.
        func textDidChange(_ notification: Notification) {
            guard let binding = parent.editableText,
                  let textView = notification.object as? NSTextView else { return }
            binding.wrappedValue = textView.string
        }
    }
}

/// Builds a styled, selectable representation of a teacher's note that mirrors
/// `FormattedTeacherNoteView` (bold headers, orange bullets) while remaining a
/// single attributed string so it can be hosted in a selectable NSTextView.
/// The `Score:` line is dropped since callers display the score separately.
func teacherNoteAttributedString(_ note: String) -> NSAttributedString {
    let result = NSMutableAttributedString()
    let bodyFont = NSFont.systemFont(ofSize: 13)
    let boldFont = NSFont.boldSystemFont(ofSize: 13)

    let lines = note.components(separatedBy: .newlines)
    var isFirstLine = true

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.contains("Score:") else { continue }

        if !isFirstLine {
            result.append(NSAttributedString(string: "\n"))
        }
        isFirstLine = false

        if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("*") {
            let content = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
            result.append(NSAttributedString(string: "•  ", attributes: [
                .font: bodyFont,
                .foregroundColor: NSColor.systemOrange
            ]))
            result.append(NSAttributedString(string: content, attributes: [
                .font: bodyFont,
                .foregroundColor: NSColor.secondaryLabelColor
            ]))
        } else if trimmed.hasSuffix(":") {
            result.append(NSAttributedString(string: trimmed, attributes: [
                .font: boldFont,
                .foregroundColor: NSColor.labelColor
            ]))
        } else {
            result.append(NSAttributedString(string: trimmed, attributes: [
                .font: bodyFont,
                .foregroundColor: NSColor.secondaryLabelColor
            ]))
        }
    }

    return result
}

/// Custom NSTextView with vocabulary support.
///
/// Builds its own context menu instead of deferring to AppKit's default rich-text
/// menu. The default menu lazily assembles Font / Spelling / Substitutions / Speech
/// submenus whose supermenu back-pointers are briefly inconsistent, which spams the
/// console with "Internal inconsistency in menus". Supplying a focused menu here
/// avoids that entirely while keeping the actions users actually need.
class VocabularyTextView: NSTextView {
    var onWordSelected: ((String, String) -> Void)?

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()

        let range = selectedRange()
        let selectedText = range.length > 0
            ? (string as NSString).substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
            : ""

        if !selectedText.isEmpty {
            let item = NSMenuItem(
                title: "Add \"\(selectedText.prefix(20))\" to Vocabulary",
                action: #selector(addSelectionToVocabulary(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = [selectedText, extractContext(at: range)]
            menu.addItem(item)
            menu.addItem(.separator())
        }

        // Standard editing actions routed through the responder chain (target: nil).
        if !selectedText.isEmpty {
            if isEditable {
                menu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "")
            }
            menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "")
        }
        if isEditable {
            menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "")
        }
        if !string.isEmpty {
            menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "")
        }

        return menu.items.isEmpty ? nil : menu
    }

    @objc private func addSelectionToVocabulary(_ sender: NSMenuItem) {
        guard let pair = sender.representedObject as? [String], pair.count == 2 else { return }
        onWordSelected?(pair[0], pair[1])
    }

    /// Extract the sentence surrounding the selection, used as lookup context.
    private func extractContext(at range: NSRange) -> String {
        let nsText = string as NSString

        var start = range.location
        var end = range.location + range.length

        while start > 0 {
            let scalar = UnicodeScalar(nsText.character(at: start - 1))
            if let scalar = scalar, CharacterSet(charactersIn: ".!?").contains(scalar) { break }
            start -= 1
        }

        while end < nsText.length {
            let scalar = UnicodeScalar(nsText.character(at: end))
            end += 1
            if let scalar = scalar, CharacterSet(charactersIn: ".!?").contains(scalar) { break }
        }

        let contextRange = NSRange(location: max(0, start), length: min(nsText.length, end) - max(0, start))
        return nsText.substring(with: contextRange).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// View for displaying text with vocabulary lookup capability (right-click a
/// word → add to vocabulary). Works for the original transcription, the editable
/// refined text, and formatted teacher notes.
struct TranscriptionTextView: View {
    let text: String
    /// When set, the text is editable and changes flow back through this binding.
    var editableText: Binding<String>? = nil
    /// Optional rich rendering (read-only) — used for formatted teacher notes.
    var attributed: NSAttributedString? = nil
    /// When true the view grows to fit its content instead of using `minHeight`.
    var selfSizing: Bool = false
    var minHeight: CGFloat = 60

    /// Identifiable carrier so the sheet is driven by `item:` (never presents
    /// with an empty/nil word, which `isPresented:` + `if let` is prone to).
    private struct PendingWord: Identifiable {
        let id = UUID()
        let word: String
        let context: String
    }

    @State private var pendingWord: PendingWord?
    @State private var measuredHeight: CGFloat = 0

    var body: some View {
        SelectableTextView(
            text: text,
            editableText: editableText,
            attributed: attributed,
            dynamicHeight: selfSizing ? $measuredHeight : nil
        ) { word, context in
            pendingWord = PendingWord(word: word, context: context)
        }
        .frame(height: selfSizing ? max(minHeight, measuredHeight) : nil)
        .frame(minHeight: selfSizing ? nil : minHeight)
        .sheet(item: $pendingWord) { pending in
            AddWordFromTranscriptionSheet(
                word: pending.word,
                context: pending.context,
                onDismiss: { pendingWord = nil }
            )
        }
    }
}

/// Sheet for adding a word from transcription
struct AddWordFromTranscriptionSheet: View {
    let word: String
    let context: String
    let onDismiss: () -> Void

    @State private var isLoading = false
    @State private var lookupResult: WordExplanation?
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var saved = false

    private let lookupService = VocabularyLookupService.shared
    private let storage = VocabularyStorage.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add to Vocabulary")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Word display
                    VStack(alignment: .leading, spacing: 4) {
                        Text(word)
                            .font(.title)
                            .fontWeight(.bold)

                        if !context.isEmpty {
                            Text("From: \"\(context)\"")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Divider()

                    // Loading state
                    if isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Looking up...")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                    }
                    // Error state
                    else if let error = errorMessage {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title)
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                lookupWord()
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    // Result state
                    else if let result = lookupResult {
                        VStack(alignment: .leading, spacing: 12) {
                            if let phonetic = result.phonetic {
                                Text(phonetic)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }

                            if let pos = result.partOfSpeech {
                                Text(pos)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }

                            if let defEN = result.definitionEN {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Definition")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(defEN)
                                        .font(.body)
                                }
                            }

                            if let defCN = result.definitionCN {
                                Text(defCN)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }

                            if let examples = result.exampleSentences, !examples.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Example")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\"\(examples[0].en)\"")
                                        .font(.body)
                                        .italic()
                                    Text(examples[0].cn)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                if saved {
                    Label("Added!", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Button(action: saveWord) {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Label("Add to Vocabulary", systemImage: "plus.circle.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(lookupResult == nil || isSaving)
                }
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .onAppear {
            lookupWord()
        }
    }

    private func lookupWord() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await lookupService.lookupWord(word, context: context)
                await MainActor.run {
                    lookupResult = result
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func saveWord() {
        guard let result = lookupResult else { return }

        isSaving = true

        Task {
            do {
                // Check for duplicate
                if storage.wordExists(result.word) {
                    await MainActor.run {
                        errorMessage = "This word already exists in your vocabulary"
                        isSaving = false
                    }
                    return
                }

                // Create entry
                try storage.addWord(
                    word: result.word,
                    phonetic: result.phonetic,
                    partOfSpeech: result.partOfSpeech,
                    definitionEN: result.definitionEN,
                    definitionCN: result.definitionCN,
                    examples: result.exampleSentencesModels,
                    synonyms: result.synonyms ?? [],
                    antonyms: result.antonyms ?? [],
                    userContext: context,
                    category: "From Transcription",
                    tags: ["transcription"],
                    sourceInteractionId: nil  // Could link to LocalInteraction if available
                )

                await MainActor.run {
                    saved = true
                    isSaving = false

                    // Auto-dismiss after short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        onDismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Preview

struct SelectableTextView_Previews: PreviewProvider {
    static var previews: some View {
        TranscriptionTextView(text: "This is a sample text for testing the selectable text view. You can select any word and add it to your vocabulary.")
            .frame(width: 400, height: 200)
            .padding()
    }
}
