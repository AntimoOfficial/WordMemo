//
//  Models.swift
//  WordMemo
//
//  Created by antimo on 2025/12/19.
//

import Foundation
import SwiftData

@Model
final class WordList {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var lastUsedAt: Date
    /// Schema flag to support non-destructive migrations later.
    var schemaVersion: Int
    @Relationship(deleteRule: .cascade, inverse: \WordEntry.list) var entries: [WordEntry] = []

    init(name: String, now: Date = .now) {
        self.id = UUID()
        self.name = name
        self.createdAt = now
        self.updatedAt = now
        self.lastUsedAt = now
        self.schemaVersion = 1
    }

    func touchUsage(at date: Date = .now) {
        lastUsedAt = date
        updatedAt = date
    }

    func markUpdated(at date: Date = .now) {
        updatedAt = date
    }
}

@Model
final class WordEntry {
    @Attribute(.unique) var id: UUID
    var term: String
    var pronunciation: String
    var partOfSpeech: String
    var definition: String
    var proficiency: Double
    var modifiedAt: Date
    var lastReviewedAt: Date?
    @Relationship(deleteRule: .nullify) var list: WordList?
    @Relationship(deleteRule: .nullify) var lemma: WordEntry?
    @Relationship(deleteRule: .nullify, inverse: \WordEntry.lemma) var derivatives: [WordEntry] = []

    init(
        term: String,
        pronunciation: String = "",
        partOfSpeech: String = "",
        definition: String = "",
        proficiency: Double = 0,
        list: WordList? = nil,
        now: Date = .now
    ) {
        self.id = UUID()
        self.term = term
        self.pronunciation = pronunciation
        self.partOfSpeech = partOfSpeech
        self.definition = definition
        self.proficiency = proficiency
        self.modifiedAt = now
        self.list = list
    }

    func touchReviewed(at date: Date = .now, delta: Double = 0) {
        lastReviewedAt = date
        applyProficiencyDelta(delta)
        modifiedAt = date
    }

    func applyProficiencyDelta(_ delta: Double) {
        proficiency = max(0, min(100, proficiency + delta))
    }

    func setLemma(_ entry: WordEntry?) {
        lemma = entry
        if let entry, entry.derivatives.contains(where: { $0.id == id }) == false {
            entry.derivatives.append(self)
        }
    }

    func addDerivative(_ entry: WordEntry?) {
        guard let entry else { return }
        if derivatives.contains(where: { $0.id == entry.id }) == false {
            derivatives.append(entry)
        }
        if entry.lemma?.id != id {
            entry.lemma = self
        }
    }
}
