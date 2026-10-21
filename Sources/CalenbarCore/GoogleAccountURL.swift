import Foundation

/// Points a Google link at one of the accounts signed into the browser (`authuser`), so the meeting
/// or the event opens with the account that was invited instead of whichever one is the default.
public enum GoogleAccountURL {
    /// Exact hosts, never suffixes: the address must not reach anyone but Google.
    private static let hosts: Set<String> = ["meet.google.com", "calendar.google.com"]

    /// Unreserved characters only; everything else in the address is percent-encoded. A raw `+` in a
    /// query reads as a space on Google's side, so `name+tag@` must travel as `%2B`.
    private static let valueCharacters = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~@")

    /// HTTPS links to Meet or Google Calendar; plain HTTP is left alone so the address never travels unencrypted.
    public static func accepts(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else { return false }
        return hosts.contains(host) && url.user == nil && url.password == nil
    }

    /// The same link with `authuser` set to this address, replacing any `authuser` it already had.
    /// Any other link comes back unchanged.
    public static func url(_ url: URL, signedInAs email: EmailAddress) -> URL {
        guard accepts(url),
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let value = email.value.addingPercentEncoding(withAllowedCharacters: valueCharacters)
        else { return url }

        let kept = (components.percentEncodedQueryItems ?? []).filter { item in
            (item.name.removingPercentEncoding ?? item.name).lowercased() != "authuser"
        }
        components.percentEncodedQueryItems = kept + [URLQueryItem(name: "authuser", value: value)]
        return components.url ?? url
    }
}
