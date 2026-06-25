// StoryActivity.swift
// Handoff NSUserActivity for "open this HN story". Advertised (lifecycle-bound)
// from the visible story surface so another of the user's Apple devices can
// continue the story; webpageURL provides a HN web fallback for devices without
// the app. v1: Handoff only — no Spotlight / prediction indexing.

import Foundation

enum StoryActivity {

    /// Must match the entry in Info.plist's NSUserActivityTypes.
    static let activityType = "com.liquidnews.openStory"

    /// Key under which the HN item id is stored in userInfo.
    static let idKey = "id"

    /// Builds a fresh activity advertising the given story.
    static func make(for story: HNItem) -> NSUserActivity {
        let activity = NSUserActivity(activityType: activityType)
        update(activity, with: story)
        return activity
    }

    /// Refreshes an existing activity's payload — used by the SwiftUI
    /// `.userActivity` update closure when the advertised story changes (A → B).
    static func update(_ activity: NSUserActivity, with story: HNItem) {
        activity.title = story.title
        activity.userInfo = [idKey: story.id]
        activity.webpageURL = URL(string: "https://news.ycombinator.com/item?id=\(story.id)")
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = false
        activity.isEligibleForPrediction = false
    }

    /// Extracts the HN item id from a continued activity's userInfo.
    static func itemID(from activity: NSUserActivity) -> Int? {
        if let id = activity.userInfo?[idKey] as? Int { return id }
        // Defensive: some transports box numbers as NSNumber/String.
        if let n = activity.userInfo?[idKey] as? NSNumber { return n.intValue }
        if let s = activity.userInfo?[idKey] as? String { return Int(s) }
        return nil
    }
}
