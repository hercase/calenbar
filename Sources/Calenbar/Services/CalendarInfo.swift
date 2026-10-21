struct CalendarInfo: Identifiable, Hashable {
    let id: String
    let title: String
    let colorHex: String
    let sourceTitle: String
    /// The account the calendar syncs from; several calendars share one.
    let sourceID: String
    /// True for calendars synced from an account (Google, Exchange, iCloud); false for local,
    /// subscribed and birthday calendars, which exist on every Mac and prove nothing.
    let isFromAccount: Bool
    /// False for subscribed and holiday calendars, which macOS will not let us write to.
    let canCreateEvents: Bool

    init(
        id: String,
        title: String,
        colorHex: String,
        sourceTitle: String,
        sourceID: String = "",
        isFromAccount: Bool,
        canCreateEvents: Bool = true
    ) {
        self.id = id
        self.title = title
        self.colorHex = colorHex
        self.sourceTitle = sourceTitle
        self.sourceID = sourceID
        self.isFromAccount = isFromAccount
        self.canCreateEvents = canCreateEvents
    }
}
