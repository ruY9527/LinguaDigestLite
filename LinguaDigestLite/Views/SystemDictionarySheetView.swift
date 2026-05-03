//
//  SystemDictionarySheetView.swift
//  LinguaDigestLite
//
//  Extracted from ReaderView.swift
//

import SwiftUI
import UIKit

/// 系统词典弹窗
struct SystemDictionarySheetView: View {
    @ObservedObject var viewModel: ReaderViewModel
    let word: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                quickLookupSummary
                Divider()
                EmbeddedSystemDictionaryView(word: word)
                    .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle(word)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("common.close")) {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(viewModel.selectableCategoriesForWord, id: \.id) { category in
                            Button {
                                viewModel.toggleCategorySelection(for: category)
                            } label: {
                                HStack {
                                    Text(category.name)
                                    if viewModel.isCategorySelectedForWord(category) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "folder")
                    }

                    Button {
                        viewModel.addToVocabulary(
                            word: word,
                            context: viewModel.selectedWordContext,
                            categoryIds: Array(viewModel.selectedCategoryIdsForWord)
                        )
                    } label: {
                        Image(systemName: "plus.circle")
                    }

                    Button {
                        viewModel.speakWord(word)
                    } label: {
                        Image(systemName: "speaker.wave.3")
                    }
                }
            }
        }
    }

    private var quickLookupSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    if let pos = viewModel.selectedWordPartOfSpeech {
                        Text(DictionaryService.displayNameForPartOfSpeech(pos))
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.12))
                            .cornerRadius(6)
                    }

                    if !viewModel.selectedCategoriesForWord.isEmpty {
                        Text(String(format: L("category.addLabel"), viewModel.selectedCategoriesForWord.map(\.name).joined(separator: "、")))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            if !viewModel.selectedWordGroupedDefinitions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("section.quickDef"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(Array(viewModel.selectedWordGroupedDefinitions.prefix(3).enumerated()), id: \.offset) { _, group in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(DictionaryService.displayNameForPartOfSpeech(group.pos))
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color(hex: DictionaryService.colorForPartOfSpeech(group.pos)).opacity(0.15))
                                .foregroundColor(Color(hex: DictionaryService.colorForPartOfSpeech(group.pos)))
                                .cornerRadius(3)

                            ForEach(Array(group.definitions.prefix(2).enumerated()), id: \.offset) { index, definition in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("\(index + 1).")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.blue)
                                    Text(definition)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                }
            } else if !viewModel.selectedWordDefinitions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("section.quickDef"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(Array(viewModel.selectedWordDefinitions.prefix(4).enumerated()), id: \.offset) { index, definition in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.blue)
                            Text(definition)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else {
                Text(L("hint.systemDictSwitched"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if let context = viewModel.selectedWordContext {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("section.context"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(context)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .background(Color(UIColor.systemBackground))
    }
}

private struct EmbeddedSystemDictionaryView: UIViewControllerRepresentable {
    let word: String

    func makeUIViewController(context: Context) -> DictionaryContainerViewController {
        let controller = DictionaryContainerViewController()
        controller.updateWord(word)
        return controller
    }

    func updateUIViewController(_ uiViewController: DictionaryContainerViewController, context: Context) {
        uiViewController.updateWord(word)
    }
}

private final class DictionaryContainerViewController: UIViewController {
    private var currentWord: String?
    private var dictionaryController: UIReferenceLibraryViewController?

    func updateWord(_ word: String) {
        guard currentWord != word else { return }
        currentWord = word
        embedDictionaryController(for: word)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    private func embedDictionaryController(for word: String) {
        if let dictionaryController {
            dictionaryController.willMove(toParent: nil)
            dictionaryController.view.removeFromSuperview()
            dictionaryController.removeFromParent()
        }

        let controller = UIReferenceLibraryViewController(term: word)
        addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controller.view)

        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        controller.didMove(toParent: self)
        dictionaryController = controller
    }
}
