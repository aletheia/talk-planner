import SwiftUI
import UIKit

/// A `UITextView`-backed editor that tracks the caret/selection so callers can
/// insert text (like a segment marker) exactly where the speaker is typing.
///
/// Insertion is requested by bumping `insertRequest` with the text to insert;
/// the coordinator splices it at the current selection, replacing any selected
/// range, and keeps the caret after the inserted text.
struct MarkdownTextEditor: UIViewRepresentable {
    @Binding var text: String
    /// Set to a non-nil value to request an insertion at the caret. Cleared once applied.
    @Binding var insertRequest: String?
    var isFocused: Bool
    var onFocusChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.font = .monospacedSystemFont(ofSize: 17, weight: .regular)
        view.backgroundColor = .clear
        view.autocorrectionType = .no
        view.autocapitalizationType = .sentences
        view.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        view.text = text
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        if view.text != text {
            let selected = view.selectedRange
            view.text = text
            view.selectedRange = clamp(selected, in: view)
        }

        if let insertion = insertRequest {
            apply(insertion, in: view, context: context)
            // Clear the request after applying (async to avoid mutating during update).
            DispatchQueue.main.async { insertRequest = nil }
        }

        if isFocused, !view.isFirstResponder {
            DispatchQueue.main.async { view.becomeFirstResponder() }
        } else if !isFocused, view.isFirstResponder {
            DispatchQueue.main.async { view.resignFirstResponder() }
        }
    }

    /// Splice `insertion` at the caret, replacing any selection, then move the caret past it.
    private func apply(_ insertion: String, in view: UITextView, context: Context) {
        let ns = view.text as NSString
        let range = clamp(view.selectedRange, in: view)
        let updated = ns.replacingCharacters(in: range, with: insertion)

        context.coordinator.isProgrammaticChange = true
        view.text = updated
        let caret = range.location + (insertion as NSString).length
        view.selectedRange = NSRange(location: caret, length: 0)
        context.coordinator.isProgrammaticChange = false

        text = updated
        if !view.isFirstResponder { view.becomeFirstResponder() }
        view.scrollRangeToVisible(view.selectedRange)
    }

    private func clamp(_ range: NSRange, in view: UITextView) -> NSRange {
        let length = (view.text as NSString).length
        let location = min(max(0, range.location), length)
        let maxLen = length - location
        return NSRange(location: location, length: min(max(0, range.length), maxLen))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private let parent: MarkdownTextEditor
        var isProgrammaticChange = false

        init(_ parent: MarkdownTextEditor) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            guard !isProgrammaticChange else { return }
            parent.text = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onFocusChange(true)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.onFocusChange(false)
        }
    }
}
