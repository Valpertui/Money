#!/usr/bin/env xcrun -sdk macosx swift

//
//  Generate.swift
//  Money
//
//  Created by Daniel Thorpe on 01/11/2015.
//
//

import Foundation

typealias Writer = (String) -> Void
typealias Generator = (Writer) -> Void

let enUS = NSLocale(localeIdentifier: "en_US")

protocol TypeGenerator {
    static var typeName: String { get }
    var displayName: String { get }
}

extension TypeGenerator {

    var name: String {
        return (displayName.capitalizedStringWithLocale(enUS) as NSString)
            .stringByReplacingOccurrencesOfString(" ", withString: "")
            .stringByReplacingOccurrencesOfString("-", withString: "")
            .stringByReplacingOccurrencesOfString("ʼ", withString: "")
            .stringByReplacingOccurrencesOfString(".", withString: "")
            .stringByReplacingOccurrencesOfString("&", withString: "")
            .stringByReplacingOccurrencesOfString("(", withString: "")
            .stringByReplacingOccurrencesOfString(")", withString: "")
            .stringByReplacingOccurrencesOfString("’", withString: "")
    }

    var caseNameValue: String {
        return ".\(name)"
    }

    var protocolName: String {
        return "\(name)\(Self.typeName)Type"
    }
}

/// MARK: - Currency Info

func createMoneyTypeForCurrency(code: String) -> String {
    return "_Money<Currency.\(code)>"
}

func createExtensionFor(typename: String, writer: Writer, content: Generator) {
    writer("extension \(typename) {")
    content(writer)
    writer("}")
}

func createFrontMatter(line: Writer) {
    line("// ")
    line("// Money, https://github.com/danthorpe/Money")
    line("// Created by Dan Thorpe, @danthorpe")
    line("// ")
    line("// The MIT License (MIT)")
    line("// ")
    line("// Copyright (c) 2015 Daniel Thorpe")
    line("// ")
    line("// Permission is hereby granted, free of charge, to any person obtaining a copy")
    line("// of this software and associated documentation files (the \"Software\"), to deal")
    line("// in the Software without restriction, including without limitation the rights")
    line("// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell")
    line("// copies of the Software, and to permit persons to whom the Software is")
    line("// furnished to do so, subject to the following conditions:")
    line("// ")
    line("// The above copyright notice and this permission notice shall be included in all")
    line("// copies or substantial portions of the Software.")
    line("// ")
    line("// THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR")
    line("// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,")
    line("// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE")
    line("// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER")
    line("// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,")
    line("// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE")
    line("// SOFTWARE.")
    line("// ")
    line("// Autogenerated from build scripts, do not manually edit this file.")
    line("")
}

func createCurrencyTypes(line: Writer) {
    for code in NSLocale.ISOCurrencyCodes() {
        line("")
        line("    /// Currency \(code)")
        line("    public final class \(code): Currency.Base, ISOCurrencyType {")
        line("        public static var sharedInstance = \(code)(code: \"\(code)\")")
        line("    }")
    }
}

func createMoneyTypes(line: Writer) {
    line("")

    for code in NSLocale.ISOCurrencyCodes() {
        line("/// \(code) Money")
        let name = createMoneyTypeForCurrency(code)
        line("public typealias \(code) = \(name)")
    }
}

/// MARK: - Locale Info

struct Country: Comparable, TypeGenerator, CustomStringConvertible {
    static let typeName = "Country"
    let id: String
    let displayName: String
    var langaugeIds = Set<String>()

    var description: String {
        return "\(self.id): \(displayName) -> \(langaugeIds)"
    }

    init?(id: String) {
        self.id = id
        guard let countryDisplayName = enUS.displayNameForKey(NSLocaleCountryCode, value: id) else {
            return nil
        }
        displayName = countryDisplayName
    }
}

struct Language: Comparable, TypeGenerator, CustomStringConvertible {
    static let typeName = "Language"

    let id: String
    let displayName: String
    var countryIds = Set<String>()

    var description: String {
        return "\(id): \(displayName) -> \(countryIds)"
    }

    var languageSpeakingCountryEnumName: String {
        return "\(name)Speaking\(Country.typeName)"
    }

    init?(id: String) {
        self.id = id
        guard let languageDisplayName = enUS.displayNameForKey(NSLocaleLanguageCode, value: id) else {
            return nil
        }
        displayName = languageDisplayName
    }
}

func ==(lhs: Country, rhs: Country) -> Bool {
    return lhs.id == rhs.id
}

func <(lhs: Country, rhs: Country) -> Bool {
    return lhs.name < rhs.name
}

func ==(lhs: Language, rhs: Language) -> Bool {
    return lhs.id == rhs.id
}

func <(lhs: Language, rhs: Language) -> Bool {
    return lhs.name < rhs.name
}

typealias LanguagesById = Dictionary<String, Language>
typealias CountriesById = Dictionary<String, Country>

struct LocaleInfo {

    let languagesById: LanguagesById
    let countriesById: CountriesById
    let languages: [Language]
    let countries: [Country]
    let languagesWithLessThanTwoCountries: [Language]
    let languagesWithMoreThanOneCountry: [Language]

    init() {
        let localeIDs = NSLocale.availableLocaleIdentifiers()
        var _countriesById = CountriesById()
        var _languagesById = LanguagesById()

        for id in localeIDs {
            let locale = NSLocale(localeIdentifier: id)
            let countryId = locale.objectForKey(NSLocaleCountryCode) as? String
            let country: Country? = countryId.flatMap { _countriesById[$0] ?? Country(id: $0) }
            let languageId = locale.objectForKey(NSLocaleLanguageCode) as? String
            let language: Language? = languageId.flatMap { _languagesById[$0] ?? Language(id: $0) }

            if let countryId = countryId, var language = language {
                language.countryIds.insert(countryId)
                _languagesById.updateValue(language, forKey: language.id)
            }

            if let languageId = languageId, var country = country {
                country.langaugeIds.insert(languageId)
                _countriesById.updateValue(country, forKey: country.id)
            }
        }

        self.languagesById = _languagesById
        self.countriesById = _countriesById

        countries = ([Country])(countriesById.values).sort { $0.langaugeIds.count > $1.langaugeIds.count }
        languages = ([Language])(languagesById.values).sort { $0.countryIds.count > $1.countryIds.count }

        languagesWithLessThanTwoCountries = languages.filter({ $0.countryIds.count < 2 }).sort()
        languagesWithMoreThanOneCountry = languages.filter({ $0.countryIds.count > 1 }).sort()
    }
}

let info = LocaleInfo()

func createLanguageSpeakingCountry(line: Writer, language: Language) {
    let name = language.languageSpeakingCountryEnumName

    line("")

    // Write the enum type
    line("public enum \(name): CountryType {")

    let _countries = language.countryIds.sort().flatMap({ info.countriesById[$0] })

    // Write the cases
    line("")
    for country in _countries {
        line("    case \(country.name)")
    }


    // Write a static constant for all
    let caseNames = _countries.map { $0.caseNameValue }
    let joinedCaseNames = caseNames.joinWithSeparator(", ")
    line("")
    line("    public static let all: [\(name)] = [ \(joinedCaseNames) ]")

    line("")
    line("    public var countryIdentifier: String {")
    line("        switch self {")

    for country in _countries {
        line("        case .\(country.name):")
        line("            return \"\(country.id)\"")
    }

    line("        }") // End of switch
    line("    }") // End of var

    line("}") // End of enum
}

func createLanguageSpeakingCountries(line: Writer) {
    line("")
    line("// MARK: - Country Types")
    for language in info.languagesWithMoreThanOneCountry {
        createLanguageSpeakingCountry(line, language: language)
    }
}

func createLocale(line: Writer) {
    line("")
    line("// MARK: - Locale")

    do {
        line("")
        line("public enum Locale {")

        // Write a static constant for all
        //            let caseNames = info.languages.map { ".\($0.name)" }
        //            let joinedCaseNames = caseNames.joinWithSeparator(", ")
        //            line("")
        //            line("    public static let all: [Locale] = [ \(joinedCaseNames) ]")

        line("")
        for language in info.languages.sort() {
            if language.countryIds.count > 1 {
                line("    case \(language.name)(\(language.languageSpeakingCountryEnumName))")
            }
            else {
                line("    case \(language.name)")
            }
        }

        line("}") // End of enum
    }

    // Add extension for LanguageType protocol
    do {
        line("")
        line("extension Locale: LanguageType {")
        line("")
        line("    public var languageIdentifier: String {")
        line("        switch self {")

        for language in info.languages.sort() {
            if language.countryIds.count > 1 {
                line("        case .\(language.name)(_):")
                line("            return \"\(language.id)\"")
            }
            else {
                line("        case .\(language.name):")
                line("            return \"\(language.id)\"")
            }
        }

        line("        }") // End of switch
        line("    }") // End of var
        line("}") // End of extension
    }

    // Add extension for CountryType protocol
    do {
        line("")
        line("extension Locale: CountryType {")
        line("")
        line("    public var countryIdentifier: String {")
        line("        switch self {")

        let caseNames = info.languagesWithLessThanTwoCountries.map { $0.caseNameValue }
        let joinedCaseNames = caseNames.joinWithSeparator(", ")
        line("        case \(joinedCaseNames):")
        line("            return \"\"")

        for language in info.languagesWithMoreThanOneCountry {
            line("        case .\(language.name)(let country):")
            line("            return country.countryIdentifier")
        }

        line("        }") // End of switch
        line("    }") // End of var
        line("}") // End of extension
    }

    // Add extension for LocaleType protocol
    do {
        line("")
        line("extension Locale: LocaleType {")
        line("    // Uses default implementation")
        line("}") // End of extension
    }
}

func createLocaleTypes(line: Writer) {

    // Create the (Language)SpeakingCountry enum types
    createLanguageSpeakingCountries(line)

    // Create the Locale enum
    createLocale(line)

}

// MARK: - Unit Tests

func createUnitTestImports(line: Writer) {
    line("import XCTest")
    line("@testable import Money")
}

func createXCTestCaseNamed(line: Writer, className: String, content: Generator) {
    line("")
    line("class \(className)Tests: XCTestCase {")
    content(line)
    line("}")
}

func createTestForCountryIentifierFromCountryCaseName(line: Writer, country: Country) {
    line("")    
    line("    func test__country_identifier_for_\(country.name)() {")
    line("        country = .\(country.name)")
    line("        XCTAssertEqual(country.countryIdentifier, \"\(country.id)\")")
    line("    }")
}

func createUnitTestClassForLanguageSpeakingCountry(line: Writer, language: Language) {
    let name = language.languageSpeakingCountryEnumName
    createXCTestCaseNamed(line, className: name) { line in
        line("")        
        line("    var country: \(name)!")
        for country in language.countryIds.flatMap({ info.countriesById[$0] }) {
            createTestForCountryIentifierFromCountryCaseName(line, country: country)
        }
    }
}

func createUnitTestClassesForLanguageSpeakingCountries(line: Writer) {
    line("")
    line("// MARK: - Country Types Tests")
    for language in info.languagesWithMoreThanOneCountry {
        createUnitTestClassForLanguageSpeakingCountry(line, language: language)
    }
}


// MARK: - Generators

func generateSourceCode(outputPath: String) {

    guard let outputStream = NSOutputStream(toFileAtPath: outputPath, append: false) else {
        fatalError("Unable to create output stream at path: \(outputPath)")
    }

    defer {
        outputStream.close()
    }

    let write: Writer = { str in
        guard let data = str.dataUsingEncoding(NSUTF8StringEncoding) else {
            fatalError("Unable to encode str: \(str)")
        }
        outputStream.write(UnsafePointer<UInt8>(data.bytes), maxLength: data.length)
    }

    let writeLine: Writer = { write("\($0)\n") }

    outputStream.open()
    createFrontMatter(writeLine)


    createExtensionFor("Currency", writer: writeLine, content: createCurrencyTypes)
    write("\n")
    createMoneyTypes(writeLine)
    write("\n")
    createLocaleTypes(writeLine)
}

func generateUnitTests(outputPath: String) {

    guard let outputStream = NSOutputStream(toFileAtPath: outputPath, append: false) else {
        fatalError("Unable to create output stream at path: \(outputPath)")
    }

    defer {
        outputStream.close()
    }

    let write: Writer = { str in
        guard let data = str.dataUsingEncoding(NSUTF8StringEncoding) else {
            fatalError("Unable to encode str: \(str)")
        }
        outputStream.write(UnsafePointer<UInt8>(data.bytes), maxLength: data.length)
    }

    let writeLine: Writer = { write("\($0)\n") }

    outputStream.open()
    createFrontMatter(writeLine)

    createUnitTestImports(writeLine)

    createUnitTestClassesForLanguageSpeakingCountries(writeLine)


}

// MARK: - Main()

print(Process.arguments)

if Process.arguments.count < 1 {
    print("Invalid usage. Requires an output path.")
    exit(1)
}

let pathToSourceCodeFile = Process.arguments[1]
generateSourceCode(pathToSourceCodeFile)

let pathToUnitTestsFile = Process.arguments[2]
generateUnitTests(pathToUnitTestsFile)

