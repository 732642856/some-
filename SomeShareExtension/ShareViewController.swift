import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let viewModel = ShareCaptureViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        let shareView = ShareCaptureView(
            viewModel: viewModel,
            onCancel: { [weak self] in
                self?.viewModel.discardUnsavedAttachments()
                self?.extensionContext?.cancelRequest(withError: ShareCaptureError.cancelled)
            },
            onSave: { [weak self] in
                self?.save()
            }
        )

        let hostingController = UIHostingController(rootView: shareView)
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)

        Task {
            await viewModel.load(from: extensionContext)
        }
    }

    @MainActor
    private func save() {
        let store = MemoStore(storageRequirement: .sharedContainerRequired)
        if store.addMemo(text: viewModel.saveText) != nil {
            extensionContext?.completeRequest(returningItems: nil)
        } else {
            viewModel.errorMessage = "保存失败，请确认 some 和分享扩展启用了同一个 App Group"
        }
    }
}

@MainActor
final class ShareCaptureViewModel: ObservableObject {
    @Published var text: String = ""
    @Published var attachments: [SharedAttachment] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty
    }

    var saveText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }

        return attachments.map(\.referenceLine).joined(separator: "\n\n")
    }

    func load(from context: NSExtensionContext?) async {
        isLoading = true
        errorMessage = nil
        attachments = []

        guard let inputItems = context?.inputItems as? [NSExtensionItem] else {
            isLoading = false
            errorMessage = "没有找到可保存的内容"
            return
        }

        var texts: [String] = []
        var urls: [URL] = []
        var loadedAttachments: [SharedAttachment] = []
        var failedAttachmentCount = 0

        for item in inputItems {
            if let title = item.attributedTitle?.string.trimmingCharacters(in: .whitespacesAndNewlines),
               !title.isEmpty {
                texts.append(title)
            }
            if let contentText = item.attributedContentText?.string.trimmingCharacters(in: .whitespacesAndNewlines),
               !contentText.isEmpty {
                texts.append(contentText)
            }

            for provider in item.attachments ?? [] {
                if let attachment = await loadAttachment(from: provider) {
                    loadedAttachments.append(attachment)
                } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let url = await loadURL(from: provider) {
                    urls.append(url)
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                          let text = await loadText(from: provider, typeIdentifier: UTType.plainText.identifier) {
                    texts.append(text)
                } else if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier),
                          let text = await loadText(from: provider, typeIdentifier: UTType.text.identifier) {
                    texts.append(text)
                } else if isSupportedAttachment(provider) {
                    failedAttachmentCount += 1
                }
            }
        }

        attachments = loadedAttachments
        text = SharedMemoTextComposer.compose(texts: texts, urls: urls, attachments: loadedAttachments)
        if text.isEmpty {
            errorMessage = "这次分享的内容暂时无法识别"
        } else if failedAttachmentCount > 0 {
            errorMessage = "\(failedAttachmentCount) 个附件没有读取成功"
        }
        isLoading = false
    }

    func discardUnsavedAttachments() {
        attachments.forEach { SharedAttachmentStore.delete($0) }
        attachments = []
    }

    private func loadText(from provider: NSItemProvider, typeIdentifier: String) async -> String? {
        await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                if let text = item as? String {
                    continuation.resume(returning: text)
                } else if let data = item as? Data {
                    continuation.resume(returning: String(decoding: data, as: UTF8.self))
                } else if let url = item as? URL {
                    continuation.resume(returning: url.absoluteString)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadAttachment(from provider: NSItemProvider) async -> SharedAttachment? {
        if let imageAttachment = await loadImageAttachment(from: provider) {
            return imageAttachment
        }

        if let fileAttachment = await loadFileAttachment(from: provider) {
            return fileAttachment
        }

        return await loadDataAttachment(from: provider)
    }

    private func loadImageAttachment(from provider: NSItemProvider) async -> SharedAttachment? {
        guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
            return nil
        }

        let typeIdentifier = provider.registeredTypeIdentifiers.first { identifier in
            UTType(identifier)?.conforms(to: .image) == true
        } ?? UTType.image.identifier

        if let attachment = await loadFileOrDataAttachment(
            from: provider,
            typeIdentifier: typeIdentifier,
            suggestedFilename: provider.suggestedName
        ) {
            return attachment
        }

        if let data = await loadDataRepresentation(from: provider, typeIdentifier: typeIdentifier) {
            return try? SharedAttachmentStore.save(
                data: data,
                suggestedFilename: provider.suggestedName,
                typeIdentifier: typeIdentifier,
                storageRequirement: .sharedContainerRequired
            )
        }

        return nil
    }

    private func loadFileAttachment(from provider: NSItemProvider) async -> SharedAttachment? {
        guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else {
            return nil
        }

        return await loadFileOrDataAttachment(
            from: provider,
            typeIdentifier: UTType.fileURL.identifier,
            suggestedFilename: provider.suggestedName
        )
    }

    private func loadDataAttachment(from provider: NSItemProvider) async -> SharedAttachment? {
        guard let typeIdentifier = provider.registeredTypeIdentifiers.first(where: { identifier in
            guard let type = UTType(identifier) else { return false }
            return type.conforms(to: .data)
                && !type.conforms(to: .url)
                && !type.conforms(to: .text)
                && !type.conforms(to: .image)
        }) else {
            return nil
        }

        return await loadFileOrDataAttachment(
            from: provider,
            typeIdentifier: typeIdentifier,
            suggestedFilename: provider.suggestedName
        )
    }

    private func loadFileOrDataAttachment(
        from provider: NSItemProvider,
        typeIdentifier: String,
        suggestedFilename: String?
    ) async -> SharedAttachment? {
        if let attachment = await loadFileRepresentationAttachment(
            from: provider,
            typeIdentifier: typeIdentifier,
            suggestedFilename: suggestedFilename
        ) {
            return attachment
        }

        return await withCheckedContinuation { (continuation: CheckedContinuation<SharedAttachment?, Never>) in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                if let url = item as? URL, url.isFileURL {
                    continuation.resume(returning: try? SharedAttachmentStore.save(
                        fileAt: url,
                        suggestedFilename: suggestedFilename,
                        typeIdentifier: typeIdentifier,
                        storageRequirement: .sharedContainerRequired
                    ))
                } else if let data = item as? Data {
                    continuation.resume(returning: try? SharedAttachmentStore.save(
                        data: data,
                        suggestedFilename: suggestedFilename,
                        typeIdentifier: typeIdentifier,
                        storageRequirement: .sharedContainerRequired
                    ))
                } else if let image = item as? UIImage, let data = image.pngData() {
                    continuation.resume(returning: try? SharedAttachmentStore.save(
                        data: data,
                        suggestedFilename: suggestedFilename,
                        typeIdentifier: UTType.png.identifier,
                        storageRequirement: .sharedContainerRequired
                    ))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadFileRepresentationAttachment(
        from provider: NSItemProvider,
        typeIdentifier: String,
        suggestedFilename: String?
    ) async -> SharedAttachment? {
        return await withCheckedContinuation { (continuation: CheckedContinuation<SharedAttachment?, Never>) in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, _ in
                guard let url = url else {
                    continuation.resume(returning: nil)
                    return
                }

                let attachment = try? SharedAttachmentStore.save(
                    fileAt: url,
                    suggestedFilename: suggestedFilename ?? url.lastPathComponent,
                    typeIdentifier: typeIdentifier,
                    storageRequirement: .sharedContainerRequired
                )
                continuation.resume(returning: attachment)
            }
        }
    }

    private func loadDataRepresentation(from provider: NSItemProvider, typeIdentifier: String) async -> Data? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { (continuation: CheckedContinuation<URL?, Never>) in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data,
                          let text = String(data: data, encoding: .utf8),
                          let url = URL(string: text) {
                    continuation.resume(returning: url)
                } else if let text = item as? String,
                          let url = URL(string: text) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func isSupportedAttachment(_ provider: NSItemProvider) -> Bool {
        provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
            || provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
            || provider.hasItemConformingToTypeIdentifier(UTType.data.identifier)
    }
}

struct ShareCaptureView: View {
    @ObservedObject var viewModel: ShareCaptureViewModel
    let onCancel: () -> Void
    let onSave: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    if viewModel.isLoading {
                        ProgressView("读取分享内容")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("存到 some")
                                .font(.system(size: 24, weight: .bold, design: .rounded))

                            TextEditor(text: $viewModel.text)
                                .focused($isFocused)
                                .frame(minHeight: 220)
                                .padding(10)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color(.separator), lineWidth: 0.5)
                                )

                            if !viewModel.attachments.isEmpty {
                                Label("\(viewModel.attachments.count) 个附件", systemImage: "paperclip")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            if let errorMessage = viewModel.errorMessage {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("保存后会自动解析 #标签，并出现在主 App 的记录流里。")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(18)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave()
                    }
                    .font(.body.weight(.semibold))
                    .disabled(!viewModel.canSave)
                }
            }
            .task {
                isFocused = true
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

private enum ShareCaptureError: LocalizedError {
    case cancelled

    var errorDescription: String? {
        "用户取消保存"
    }
}
