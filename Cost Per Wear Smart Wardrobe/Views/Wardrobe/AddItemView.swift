import SwiftUI
import PhotosUI
import CoreData

// MARK: - Add / Edit Item

struct AddItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    /// If non-nil, the view operates in **edit** mode.
    var editingItem: WardrobeItem?

    @State private var name = ""
    @State private var category = "Tops"
    @State private var brand = ""
    @State private var priceText = ""
    @State private var purchaseDate = Date()

    // Photo
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var photoCleared = false

    @State private var showCamera = false
    @State private var showValidationAlert = false

    private var isEditing: Bool { editingItem != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                CPWTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: CPWTheme.sectionSpacing) {

                        // Photo Section
                        photoSection

                        // Details Section
                        VStack(spacing: 16) {
                            fieldRow(title: "Name") {
                                TextField("e.g. Navy Blazer", text: $name)
                                    .textFieldStyle(.plain)
                                    .font(CPWTheme.bodyFont)
                            }

                            fieldRow(title: "Category") {
                                Picker("Category", selection: $category) {
                                    ForEach(CPWTheme.categories, id: \.self) { cat in
                                        HStack {
                                            Image(systemName: CPWTheme.categoryIcons[cat] ?? "hanger")
                                            Text(cat)
                                        }
                                        .tag(cat)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(CPWTheme.primaryText)
                            }

                            fieldRow(title: "Brand (optional)") {
                                TextField("e.g. Uniqlo", text: $brand)
                                    .textFieldStyle(.plain)
                                    .font(CPWTheme.bodyFont)
                            }

                            fieldRow(title: "Price") {
                                HStack {
                                    Text(CurrencyManager.shared.currencySymbol)
                                        .foregroundStyle(CPWTheme.secondaryText)
                                    TextField("0.00", text: $priceText)
                                        .textFieldStyle(.plain)
                                        .keyboardType(.decimalPad)
                                        .font(CPWTheme.bodyFont)
                                }
                            }

                            fieldRow(title: "Purchase Date") {
                                DatePicker("", selection: $purchaseDate, in: ...Date(), displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(CPWTheme.accent)
                            }
                        }
                        .padding(CPWTheme.cardPadding)
                        .cpwCard()
                        .padding(.horizontal, CPWTheme.cardPadding)

                        // Save Button
                        Button(action: saveItem) {
                            Text(isEditing ? "Save Changes" : "Save Item")
                                .font(CPWTheme.headlineFont)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(canSave ? CPWTheme.accentGradient : LinearGradient(colors: [CPWTheme.secondaryText.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                                .clipShape(RoundedRectangle(cornerRadius: CPWTheme.cornerRadius, style: .continuous))
                        }
                        .disabled(!canSave)
                        .padding(.horizontal, CPWTheme.cardPadding)

                        DisclaimerFooter()
                            .padding(.bottom, 20)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle(isEditing ? "Edit Item" : "Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(CPWTheme.secondaryText)
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker(image: $selectedImage)
                    .ignoresSafeArea()
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                        photoCleared = false
                    }
                }
            }
            .alert("Missing Information", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please add a name and price for your item.")
            }
            .onAppear {
                populateFieldsIfEditing()
            }
        }
    }

    // MARK: - Populate Fields for Editing

    private func populateFieldsIfEditing() {
        guard let item = editingItem else { return }
        name = item.name ?? ""
        category = item.category ?? "Tops"
        brand = item.brand ?? ""
        priceText = String(format: "%.2f", item.purchasePrice)
        purchaseDate = item.purchaseDate ?? Date()

        if let photoData = item.photoData, let image = UIImage(data: photoData) {
            selectedImage = image
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: CPWTheme.largeCornerRadius, style: .continuous)
                    .fill(CPWTheme.cardBackground)
                    .frame(height: 220)
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)

                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: CPWTheme.largeCornerRadius, style: .continuous))
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "camera")
                            .font(.system(size: 40, weight: .ultraLight))
                            .foregroundStyle(CPWTheme.secondaryText.opacity(0.5))
                        Text("Add a photo")
                            .font(CPWTheme.captionFont)
                            .foregroundStyle(CPWTheme.secondaryText)
                    }
                }
            }
            .padding(.horizontal, CPWTheme.cardPadding)

            HStack(spacing: 16) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Gallery", systemImage: "photo.on.rectangle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(CPWTheme.primaryText)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(CPWTheme.cardBackground)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                }

                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Camera", systemImage: "camera")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(CPWTheme.primaryText)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(CPWTheme.cardBackground)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                    }
                }

                if selectedImage != nil {
                    Button {
                        selectedImage = nil
                        selectedPhotoItem = nil
                        photoCleared = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(CPWTheme.secondaryText)
                    }
                }
            }
        }
    }

    // MARK: - Field Row

    private func fieldRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(CPWTheme.secondaryText)
                .textCase(.uppercase)
                .tracking(0.5)
            content()
            Divider()
        }
    }

    // MARK: - Validation

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Double(priceText.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }

    // MARK: - Save

    private func saveItem() {
        guard canSave else {
            showValidationAlert = true
            return
        }

        let price = Double(priceText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedBrand = brand.trimmingCharacters(in: .whitespaces)

        if let item = editingItem {
            // --- Edit mode ---
            let newPhotoData: Data? = {
                if photoCleared && selectedImage == nil {
                    return nil
                }
                if let img = selectedImage {
                    return ImageCompressor.compress(image: img)
                }
                return item.photoData
            }()

            PersistenceController.shared.updateItem(
                item,
                name: trimmedName,
                category: category,
                brand: trimmedBrand.isEmpty ? nil : trimmedBrand,
                purchasePrice: price,
                purchaseDate: purchaseDate,
                photoData: newPhotoData
            )
        } else {
            // --- Add mode ---
            let photoData = ImageCompressor.compress(image: selectedImage ?? UIImage())

            let _ = PersistenceController.shared.createItem(
                name: trimmedName,
                category: category,
                brand: trimmedBrand.isEmpty ? nil : trimmedBrand,
                purchasePrice: price,
                purchaseDate: purchaseDate,
                photoData: selectedImage != nil ? photoData : nil
            )
        }

        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)

        dismiss()
    }
}

#Preview {
    AddItemView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
