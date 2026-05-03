//
//  TextTranslationViewModel.swift
//  LinguaDigestLite
//
//  Handles selected text translation independently from word lookup.
//

import Foundation

final class TextTranslationViewModel: ObservableObject {
    @Published var selectedText: String?
    @Published var selectedRange: NSRange?
    @Published var showingNativeTranslation: Bool = false
    @Published var showingFallbackSheet: Bool = false
    @Published var clearSelectionRequestID: Int = 0

    let availableServices: [TranslationServiceType]

    private let translationService: TranslationService

    init(translationService: TranslationService = .shared) {
        self.translationService = translationService
        self.availableServices = translationService.availableTranslationServiceTypes()
    }

    func requestTranslation(for text: String, range: NSRange? = nil) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.count >= 2 else { return }

        selectedText = trimmedText
        selectedRange = range

        if translationService.supportsNativeTranslationPresentation {
            showingNativeTranslation = true
        } else {
            showingFallbackSheet = true
        }
    }

    func translateWithService(_ serviceType: TranslationServiceType) {
        guard let selectedText, !selectedText.isEmpty else { return }
        translationService.translate(text: selectedText, serviceType: serviceType)
    }

    func close() {
        showingNativeTranslation = false
        showingFallbackSheet = false
        selectedText = nil
        selectedRange = nil
        clearSelectionRequestID += 1
    }
}
