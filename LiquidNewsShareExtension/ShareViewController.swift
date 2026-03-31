// ShareViewController.swift
// Share extension that intercepts HN story URLs and opens them in LiquidNews.
// Extracts the item ID from the shared URL and opens liquidnews://story/{id}.
// Non-HN URLs are silently ignored.

import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            finish()
            return
        }

        let urlTypeID = UTType.url.identifier

        for provider in attachments where provider.hasItemConformingToTypeIdentifier(urlTypeID) {
            provider.loadItem(forTypeIdentifier: urlTypeID) { [weak self] loaded, _ in
                guard let self else { return }

                let url: URL?
                if let u = loaded as? URL {
                    url = u
                } else if let s = loaded as? String {
                    url = URL(string: s)
                } else {
                    url = nil
                }

                guard let sharedURL = url,
                      sharedURL.host?.hasSuffix("ycombinator.com") == true,
                      sharedURL.path == "/item",
                      let idValue = URLComponents(url: sharedURL, resolvingAgainstBaseURL: false)?
                          .queryItems?.first(where: { $0.name == "id" })?.value,
                      let appURL = URL(string: "liquidnews://story/\(idValue)") else {
                    DispatchQueue.main.async { self.finish() }
                    return
                }

                DispatchQueue.main.async {
                    self.extensionContext?.open(appURL) { _ in self.finish() }
                }
            }
            return
        }

        finish()
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
