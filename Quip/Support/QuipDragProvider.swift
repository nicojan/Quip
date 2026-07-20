import Foundation
import UniformTypeIdentifiers

/// Builds the drag payload for a GIF cell. Kept out of the view so it can be
/// tested directly (see `CollectionDropTests`) — the two representations it
/// registers are load-bearing and easy to break silently.
///
/// One `NSItemProvider`, two representations:
/// - the downloadable `.gif` **file** (`.all` visibility) — drag-to-insert into
///   Messages, Finder, Slack, downloaded on demand with an HTTP-status guard so a
///   CDN error page never drops as a broken attachment;
/// - the whole GIF as JSON under a private type (`.ownProcess` visibility) — so a
///   cell can be dropped onto a collection chip to file it, without that payload
///   ever leaving Quip.
enum QuipDragProvider {
    static func make(for gif: Gif) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.suggestedName = "quip.gif"

        // In-app filing payload: the whole GIF, kept to this process.
        if let data = QuipDragType.encode(gif) {
            provider.registerDataRepresentation(
                forTypeIdentifier: QuipDragType.gifRef.identifier, visibility: .ownProcess
            ) { completion in
                completion(data, nil)
                return nil
            }
        }

        let urlString = gif.gifURL
        provider.registerFileRepresentation(
            forTypeIdentifier: UTType.gif.identifier, fileOptions: [], visibility: .all
        ) { completion in
            guard let url = URL(string: urlString) else {
                completion(nil, false, nil)
                return nil
            }
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                // Reject a non-2xx CDN response so a downloaded error page never
                // drops into Messages/Finder as a broken .gif attachment.
                guard let data,
                      let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    completion(nil, false, error); return
                }
                let file = TempClips.newGifURL()
                do {
                    try data.write(to: file)
                    completion(file, false, nil)
                } catch {
                    completion(nil, false, error)
                }
            }
            task.resume()
            return nil
        }
        return provider
    }
}
