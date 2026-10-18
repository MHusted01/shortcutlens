public extension MenuCache {
    /// A copy with the content of one menu read stored for `key`.
    ///
    /// An empty read is never cached: it usually means the menus could not be
    /// read (not ready yet, or the app hung), and a cached empty value would
    /// show "no shortcuts" instead of the loading state on the next open. A
    /// read that spent its budget only fills an empty slot.
    func storing<Element>(
        read content: OverlayContent<Element>,
        for key: Key,
        budgetSpent: Bool
    ) -> Self where Value == OverlayContent<Element> {
        guard !content.isEmpty else {
            return self
        }
        return storing(content, for: key, isComplete: !budgetSpent)
    }
}
