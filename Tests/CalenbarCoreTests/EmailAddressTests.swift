import Foundation
import Testing

@testable import CalenbarCore

struct EmailAddressTests {
    @Test func trimsAndLowercasesTheDomainOnly() throws {
        let email = try #require(EmailAddress("  Juan.Perez@Empresa.COM \n"))
        #expect(email.value == "Juan.Perez@empresa.com")
        #expect(email.canonical == "juan.perez@empresa.com")
    }

    @Test func comparesIgnoringCase() {
        #expect(EmailAddress("JUAN@empresa.com") == EmailAddress("juan@EMPRESA.com"))
    }

    @Test func googlemailIsGmail() {
        #expect(EmailAddress("juan@googlemail.com") == EmailAddress("juan@gmail.com"))
    }

    @Test func dotsAndTagsAreDifferentAddresses() {
        #expect(EmailAddress("juan.perez@empresa.com") != EmailAddress("juanperez@empresa.com"))
        #expect(EmailAddress("juan+work@empresa.com") != EmailAddress("juan@empresa.com"))
    }

    @Test func acceptsEventKitMailtoForm() throws {
        let email = try #require(EmailAddress("MAILTO:juan@empresa.com"))
        #expect(email.value == "juan@empresa.com")
    }

    @Test func keepsPlusTagsAndApostrophes() {
        #expect(EmailAddress("juan+meet@empresa.com")?.value == "juan+meet@empresa.com")
        #expect(EmailAddress("o'brien@empresa.ie")?.value == "o'brien@empresa.ie")
    }

    @Test(arguments: [
        "", " ", "Google", "Work", "juan", "@empresa.com", "juan@", "juan@@empresa.com", "a@b@empresa.com",
        "juan perez@empresa.com", "juan@empresa .com", "juan@empresa", "juan@.empresa.com", "juan@empresa.com.",
        "juan@empresa..com", ".juan@empresa.com", "juan.@empresa.com", "ju..an@empresa.com", "juan@-empresa.com",
        "juan@empresa-.com", "<juan@empresa.com>", "\"juan\"@empresa.com", "juan@empresa.com\nbcc@evil.com",
        "juan\u{0}@empresa.com", "juan@empresa.com&authuser=1", "juan@empresa.com#x", "juan?x@empresa.com",
        "juan/x@empresa.com", "josé@empresa.com", "juan@empresá.com", "😀@empresa.com", "juan@empresa_x.com",
    ])
    func rejects(_ raw: String) {
        #expect(EmailAddress(raw) == nil)
    }

    @Test func rejectsOverlongParts() {
        #expect(EmailAddress(String(repeating: "a", count: 65) + "@empresa.com") == nil)
        #expect(EmailAddress(String(repeating: "a", count: 64) + "@empresa.com") != nil)
        let longDomain = (0..<5).map { _ in String(repeating: "d", count: 60) }.joined(separator: ".") + ".com"
        #expect(EmailAddress("juan@" + longDomain) == nil)
        #expect(EmailAddress("juan@" + String(repeating: "d", count: 64) + ".com") == nil)
    }
}
