//
//  SelectableTextView.swift
//  MindFlow
//
//  Text view with word selection for vocabulary lookup
//

import SwiftUI
import AppKit

/// A text view that allows selecting words to add to vocabulary
struct SelectableTextView: NSViewRepresentable {
    let text: String
    let onWordSelected: (String, String) -> Void  // (word, context)

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = VocabularyTextView()
        textView.string = text
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .labelColor
        textView.delegate = context.coordinator
        textView.allowsUndo = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false

        // Configure text container
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        if let textView = scrollView.documentView as? NSTextView {
            if textView.string != text {
                textView.string = text
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: text, onWordSelected: onWordSelected)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        let text: String
        let onWordSelected: (String, String) -> Void

        init(text: String, onWordSelected: @escaping (String, String) -> Void) {
            self.text = text
            self.onWordSelected = onWordSelected
        }

        func textView(_ textView: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
            let selectedRange = textView.selectedRange()
            guard selectedRange.length > 0 else { return menu }

            let selectedText = (textView.string as NSString).substring(with: selectedRange).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !selectedText.isEmpty else { return menu }

            // Get context (surrounding sentence)
            let context = extractContext(from: textView.string, at: selectedRange)

            // Create custom menu
            let customMenu = NSMenu()

            // Add vocabulary lookup item
            let lookupItem = NSMenuItem(
                title: "Add \"\(selectedText.prefix(20))\" to Vocabulary",
                action: #selector(addToVocabulary(_:)),
                keyEquivalent: ""
            )
            lookupItem.representedObject = (selectedText, context)
            lookupItem.target = self
            customMenu.addItem(lookupItem)

            customMenu.addItem(NSMenuItem.separator())

            // Add original menu items
            for item in menu.items {
                customMenu.addItem(item.copy() as! NSMenuItem)
            }

            return customMenu
        }

        @objc func addToVocabulary(_ sender: NSMenuItem) {
            guard let (word, context) = sender.representedObject as? (String, String) else { return }
            onWordSelected(word, context)
        }

        private func extractContext(from text: String, at range: NSRange) -> String {
            // Try to extract the sentence containing the selection
            let nsText = text as NSString

            // Find sentence boundaries
            var start = range.location
            var end = range.location + range.length

            // Search backward for sentence start
            while start > 0 {
                let char = nsText.character(at: start - 1)
                let scalar = UnicodeScalar(char)
                if let scalar = scalar, CharacterSet(charactersIn: ".!?").contains(scalar) {
                    break
                }
                start -= 1
            }

            // Search forward for sentence end
            while end < nsText.length {
                let char = nsText.character(at: end)
                let scalar = UnicodeScalar(char)
                if let scalar = scalar, CharacterSet(charactersIn: ".!?").contains(scalar) {
                    end += 1
                    break
                }
                end += 1
            }

            // Extract context with some padding
            let contextStart = max(0, start)
            let contextEnd = min(nsText.length, end)
            let contextRange = NSRange(location: contextStart, length: contextEnd - contextStart)

            return nsText.substring(with: contextRange).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

/// Custom NSTextView with vocabulary support
class VocabularyTextView: NSTextView {
    override func menu(for event: NSEvent) -> NSMenu? {
        // Let the delegate handle menu creation
        return super.menu(for: event)
    }
}

/// View for displaying transcription text with vocabulary lookup capability
struct TranscriptionTextView: View {
    let text: String
    @State private var selectedWord: String?
    @State private var selectedContext: String?
    @State private var showAddWordSheet = false
    @State private var isLookingUp = false
    @State private var lookupResult: WordExplanation?
    @State private var lookupError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SelectableTextView(text: text) { word, context in
                selectedWord = word
                selectedContext = context
                showAddWordSheet = true
            }
            .frame(minHeight: 60)
        }
        .sheet(isPresented: $showAddWordSheet) {
            if let word = selectedWord {
                AddWordFromTranscriptionSheet(
                    word: word,
                    context: selectedContext ?? "",
                    onDismiss: {
                        showAddWordSheet = false
                        selectedWord = nil
                        selectedContext = nil
                    }
                )
            }
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
