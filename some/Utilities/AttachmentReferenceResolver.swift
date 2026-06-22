import Foundation
import UniformTypeIdentifiers

enum AttachmentReferenceResolver {
    static func relativePath(in uri: String) -> String? {
        guard let components = URLComponents(string: uri),
              components.scheme == SharedAttachmentStore.referenceScheme else {
            return nil
        }

        let encodedPath = components.host?.isEmpty == false
            ? components.host
            : components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return encodedPath?.removingPercentEncoding
    }

    static func attachment(from asset: MemoAsset) -> SharedAttachment? {
        guard let uri = asset.uri,
              let relativePath = relativePath(in: uri) else {
            return nil
        }

        return SharedAttachment(
            id: relativePath,
            filename: asset.title,
            relativePath: relativePath,
            typeIdentifier: asset.typeIdentifier ?? UTType.data.identifier,
            byteCount: asset.byteCount ?? 0
        )
    }
}
