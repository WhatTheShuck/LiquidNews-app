// PreviewData.swift
// Static sample data used exclusively in SwiftUI #Preview blocks.
// Never used in production — it's just here so previews look realistic.

import Foundation

enum PreviewData {

    // MARK: - Sample stories

    static let stories: [HNItem] = [
        HNItem(
            id: 39_896_828,
            type: .story,
            by: "ingve",
            time: Date().timeIntervalSince1970 - 3_600,
            title: "Jujutsu: A New Approach to Python Packaging",
            url: "https://astral.sh/blog/uv",
            score: 1_204,
            descendants: 342,
            text: nil,
            kids: [39_897_001, 39_897_042, 39_897_115],
            deleted: nil,
            dead: nil
        ),
        HNItem(
            id: 39_893_060,
            type: .story,
            by: "todsacerdoti",
            time: Date().timeIntervalSince1970 - 7_200,
            title: "Mistral releases Codestral: a 22B model trained on 80+ languages",
            url: "https://mistral.ai/news/codestral",
            score: 876,
            descendants: 201,
            text: nil,
            kids: [39_894_001],
            deleted: nil,
            dead: nil
        ),
        HNItem(
            id: 39_890_123,
            type: .story,
            by: "dang",
            time: Date().timeIntervalSince1970 - 10_800,
            title: "Ask HN: What are you building this weekend?",
            url: nil,
            score: 543,
            descendants: 489,
            text: "The usual thread — share what you&#x27;re hacking on.",
            kids: [39_891_001, 39_891_002],
            deleted: nil,
            dead: nil
        ),
        HNItem(
            id: 39_887_554,
            type: .story,
            by: "bko",
            time: Date().timeIntervalSince1970 - 21_600,
            title: "Researchers discover new mechanism for high-temperature superconductivity",
            url: "https://physics.aps.org/articles/v17/58",
            score: 1_892,
            descendants: 412,
            text: nil,
            kids: nil,
            deleted: nil,
            dead: nil
        ),
        HNItem(
            id: 39_881_002,
            type: .story,
            by: "fanf2",
            time: Date().timeIntervalSince1970 - 86_400,
            title: "The filesystem is a database (and it's not that bad)",
            url: "https://blog.dotat.at/2024-04-26-filesystem-database.html",
            score: 723,
            descendants: 178,
            text: nil,
            kids: nil,
            deleted: nil,
            dead: nil
        ),
    ]

    // MARK: - Sample comments

    static let topComment = HNItem(
        id: 39_897_001,
        type: .comment,
        by: "pjmlp",
        time: Date().timeIntervalSince1970 - 1_800,
        title: nil,
        url: nil,
        score: nil,
        descendants: nil,
        text: "This is really impressive. The dependency resolution approach reminds me of what Nix has been doing for years, but with a much smoother UX story for Python users. The performance numbers are wild — 10-100x faster than pip.",
        kids: [39_897_042, 39_897_043],
        deleted: nil,
        dead: nil
    )

    static let childComment = HNItem(
        id: 39_897_042,
        type: .comment,
        by: "ykonstant",
        time: Date().timeIntervalSince1970 - 900,
        title: nil,
        url: nil,
        score: nil,
        descendants: nil,
        text: "Agreed. Though I&#x27;d argue the UX is the whole game here. Nix is incredibly powerful but the learning curve scares most people off before they see the benefits.",
        kids: nil,
        deleted: nil,
        dead: nil
    )

    /// A comment with rich HTML formatting — used to preview CommentBodyView.
    static let richComment = HNItem(
        id: 39_897_200,
        type: .comment,
        by: "simonw",
        time: Date().timeIntervalSince1970 - 1_200,
        title: nil,
        url: nil,
        score: nil,
        descendants: nil,
        text: "The <i>real</i> advantage here is zero-setup execution. You can ship a one-liner that just works on any machine with uv installed:<p><pre><code>uv run --with httpx python -c \"\nimport httpx\nprint(httpx.get(&#x27;https://httpbin.org/ip&#x27;).json())\n\"</code></pre><p>No venv, no <code>pip install</code>, no requirements file. Compare that to the old approach — <b>six commands</b> before you can even run your script.<p>The performance numbers are genuinely wild too. See the benchmarks at <a href=\"https://astral.sh/blog/uv-unified-python-packaging\" rel=\"nofollow\">https://astral.sh/blog/uv-unified-python-packaging</a> — resolving a complex dependency tree in under 100ms versus pip&#x27;s 30+ seconds.",
        kids: nil,
        deleted: nil,
        dead: nil
    )
}
