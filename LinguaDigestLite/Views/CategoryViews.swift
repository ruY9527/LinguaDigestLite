//
//  CategoryViews.swift
//  LinguaDigestLite
//
//  Extracted from VocabularyListView.swift
//

import SwiftUI

/// 分类列表视图
struct CategoryListView: View {
    @ObservedObject var viewModel: VocabularyViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddCategory: Bool = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.categories, id: \.id) { category in
                    Button {
                        viewModel.selectCategory(category)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(Color(hex: category.color))
                                .frame(width: 30)

                            VStack(alignment: .leading) {
                                Text(category.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                if let description = category.description {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Text("\(viewModel.vocabularyCountForCategory(category))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: category.color).opacity(0.2))
                                .cornerRadius(8)

                            if viewModel.selectedCategory?.id == category.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        if !category.isDefault {
                            Button(role: .destructive) {
                                viewModel.deleteCategory(category)
                            } label: {
                                Label(L("common.delete"), systemImage: "trash")
                            }
                        }

                        Button {
                            // 编辑分类
                        } label: {
                            Label(L("common.edit"), systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
            .navigationTitle(L("nav.selectCategory"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("common.close")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddCategory = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCategory, onDismiss: {
                viewModel.loadCategories()
            }) {
                AddCategoryView(viewModel: viewModel)
            }
            .onAppear {
                viewModel.loadCategories()
            }
        }
    }
}

/// 添加分类视图
struct AddCategoryView: View {
    @ObservedObject var viewModel: VocabularyViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var selectedColor: String = "#007AFF"
    @State private var selectedIcon: String = "folder"

    var body: some View {
        NavigationStack {
            Form {
                Section(L("section.categoryInfo")) {
                    TextField(L("category.namePlaceholder"), text: $name)
                    TextField(L("category.descPlaceholder"), text: $description)
                }

                Section(L("section.color")) {
                    HStack(spacing: 12) {
                        ForEach(VocabularyCategory.availableColors, id: \.hex) { color in
                            Button {
                                selectedColor = color.hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: color.hex))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: selectedColor == color.hex ? 3 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section(L("section.icon")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(VocabularyCategory.availableIcons, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .frame(width: 40, height: 40)
                                        .background(selectedIcon == icon ? Color.blue.opacity(0.2) : Color.clear)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        if !name.isEmpty {
                            viewModel.addCategory(
                                name: name,
                                description: description.isEmpty ? nil : description,
                                color: selectedColor,
                                icon: selectedIcon
                            )
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text(L("action.createCategory"))
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
            .navigationTitle(L("nav.newCategory"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("common.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
