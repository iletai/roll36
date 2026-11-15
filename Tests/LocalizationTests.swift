import Foundation
import Testing

/// Guards the hand-maintained string catalogs (`Localizable.xcstrings`, `InfoPlist.xcstrings`):
/// every translatable key has en + vi, format specifiers survive translation, nothing is left untranslated.
struct LocalizationTests {
    private struct Entry {
        let key: String
        let translatable: Bool
        /// Language code -> every string unit as (state, value); plural variations contribute one unit per category.
        let units: [String: [(state: String, value: String)]]
        /// Language code -> value used for the "same as English" check (the `other` plural form when plural).
        let representative: [String: String]
    }

    /// Terms that are identical in English and Vietnamese on purpose (loanwords, brand or technical terms).
    private static let sameAsEnglishAllowList: Set<String> = ["Camera", "OK", "Halation", "CFBundleDisplayName"]

    private static let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("App/Resources")

    private static func load(_ name: String) throws -> [Entry] {
        let data = try Data(contentsOf: resources.appendingPathComponent(name))
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(root["strings"] as? [String: [String: Any]])
        return strings.map { key, body in
            var units: [String: [(state: String, value: String)]] = [:]
            var representative: [String: String] = [:]
            let localizations = body["localizations"] as? [String: [String: Any]] ?? [:]
            for (language, localization) in localizations {
                if let unit = localization["stringUnit"] as? [String: String] {
                    units[language] = [(unit["state"] ?? "", unit["value"] ?? "")]
                    representative[language] = unit["value"] ?? ""
                }
                if let plural = (localization["variations"] as? [String: Any])?["plural"] as? [String: [String: [String: String]]] {
                    units[language] = plural.values.compactMap { $0["stringUnit"] }.map { ($0["state"] ?? "", $0["value"] ?? "") }
                    representative[language] = plural["other"]?["stringUnit"]?["value"] ?? ""
                }
            }
            return Entry(
                key: key,
                translatable: body["shouldTranslate"] as? Bool ?? true,
                units: units,
                representative: representative
            )
        }.sorted { $0.key < $1.key }
    }

    nonisolated private static let catalogNames = ["Localizable.xcstrings", "InfoPlist.xcstrings"]

    /// Specifier types in order, e.g. "%1$lld of %2$@" -> ["d", "@"]. `%%` is ignored and length modifiers are dropped.
    private static func specifiers(in text: String) -> [String] {
        let stripped = text.replacingOccurrences(of: "%%", with: "")
        guard let regex = try? NSRegularExpression(pattern: "%(?:\\d+\\$)?(?:ll|l|h)?([dDuUxXfeEgGcCsS@])") else { return [] }
        let range = NSRange(stripped.startIndex..., in: stripped)
        return regex.matches(in: stripped, range: range).compactMap { match in
            Range(match.range(at: 1), in: stripped).map { String(stripped[$0]) }
        }
    }

    @Test(arguments: catalogNames)
    func everyKeyHasTranslatedEnAndVi(catalog: String) throws {
        let entries = try Self.load(catalog)
        #expect(!entries.isEmpty)
        for entry in entries where entry.translatable {
            for language in ["en", "vi"] {
                let units = entry.units[language] ?? []
                #expect(!units.isEmpty, "\(entry.key): missing \(language)")
                #expect(units.allSatisfy { $0.state == "translated" }, "\(entry.key): \(language) not translated")
                #expect(entry.representative[language] != nil, "\(entry.key): \(language) has no value/other form")
            }
        }
    }

    @Test(arguments: catalogNames)
    func formatSpecifiersMatchKey(catalog: String) throws {
        for entry in try Self.load(catalog) where entry.translatable {
            let expected = Self.specifiers(in: entry.key)
            for (language, units) in entry.units {
                for unit in units {
                    #expect(Self.specifiers(in: unit.value) == expected, "\(entry.key) [\(language)]: \(unit.value)")
                }
            }
        }
    }

    @Test(arguments: catalogNames)
    func viIsNotEmptyOrLeftInEnglish(catalog: String) throws {
        for entry in try Self.load(catalog) where entry.translatable {
            let vi = entry.units["vi"] ?? []
            #expect(vi.allSatisfy { !$0.value.trimmingCharacters(in: .whitespaces).isEmpty }, "\(entry.key): empty vi")
            guard !Self.sameAsEnglishAllowList.contains(entry.key) else { continue }
            #expect(entry.representative["vi"] != entry.representative["en"], "\(entry.key): vi equals en")
        }
    }

    @Test func positionalSpecifiersCoverEveryArgument() throws {
        // Multi-argument vi strings may reorder arguments; every index 1...n must appear exactly once.
        let regex = try NSRegularExpression(pattern: "%(\\d+)\\$")
        for entry in try Self.load("Localizable.xcstrings") where entry.translatable {
            for unit in entry.units["vi"] ?? [] {
                let range = NSRange(unit.value.startIndex..., in: unit.value)
                let indexes = regex.matches(in: unit.value, range: range).compactMap { match in
                    Range(match.range(at: 1), in: unit.value).flatMap { Int(unit.value[$0]) }
                }
                guard !indexes.isEmpty else { continue }
                #expect(indexes.sorted() == Array(1 ... Self.specifiers(in: entry.key).count), "\(entry.key): \(unit.value)")
            }
        }
    }
}
