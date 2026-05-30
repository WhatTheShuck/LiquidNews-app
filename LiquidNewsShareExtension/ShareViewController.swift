// ShareViewController.swift
// Share extension: extracts the HN story ID from a shared URL and opens it in LiquidNews.

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
                if let u = loaded as? URL { url = u }
                else if let s = loaded as? String { url = URL(string: s) }
                else { url = nil }

                guard let sharedURL = url,
                      sharedURL.host?.hasSuffix("ycombinator.com") == true,
                      sharedURL.path == "/item",
                      let idValue = URLComponents(url: sharedURL, resolvingAgainstBaseURL: false)?
                          .queryItems?.first(where: { $0.name == "id" })?.value,
                      let appURL = URL(string: "liquidnews://item/\(idValue)") else {
                    DispatchQueue.main.async { self.finish() }
                    return
                }

                DispatchQueue.main.async {
                    self.openInContainingApp(appURL)
                }
            }
            return
        }

        finish()
    }

    // extensionContext?.open(_:) only works in Today widgets, not share extensions.
    // Walk the responder chain to reach UIApplication in the host process.
    // iOS 18 requires a typed cast; older iOS uses the openURL: selector.
    private func openInContainingApp(_ url: URL) {
        var responder: UIResponder? = self

        if #available(iOS 18.0, *) {
            while let r = responder {
                if let app = r as? UIApplication {
                    app.open(url, options: [:], completionHandler: nil)
                }
                responder = r.next
            }
        } else {
            let selector = sel_registerName("openURL:")
            while let r = responder {
                if r.responds(to: selector) {
                    r.perform(selector, with: url)
                }
                responder = r.next
            }
        }

        finish()
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
