//
//  ContentView.swift
//  WordMemo
//
//  Created by antimo on 2025/12/19.
//

import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [
        SortDescriptor(\WordList.lastUsedAt, order: .reverse),
        SortDescriptor(\WordList.createdAt, order: .reverse)
    ]) private var lists: [WordList]

    @State private var selectedList: WordList?
    @State private var startStudy: Bool = false
    @State private var hasBootstrapped = false

    var body: some View {
        TabView {
            NavigationStack {
                HomeView(
                    lists: lists,
                    selectedList: $selectedList,
                    onSelectList: selectList,
                    onStartStudy: { startStudy = true }
                )
                .navigationDestination(isPresented: $startStudy) {
                    if let list = selectedList {
                        StudySessionView(list: list)
                    } else {
                        Text("请选择单词本")
                    }
                }
            }
            .tabItem {
                Label("首页", systemImage: "house")
            }

            NavigationStack {
                WordListsView(
                    lists: lists,
                    selectedList: $selectedList,
                    onSelectList: selectList
                )
            }
            .tabItem {
                Label("单词本", systemImage: "book")
            }

            NavigationStack {
                SettingsView(lists: lists, selectedList: $selectedList)
            }
            .tabItem {
                Label("个人设置", systemImage: "person.crop.circle")
            }
        }
        .onAppear { bootstrapIfNeeded() }
        .onChange(of: lists) { _ in ensureSelection() }
    }

    private func bootstrapIfNeeded() {
        guard hasBootstrapped == false else { return }
        hasBootstrapped = true
        if lists.isEmpty {
            let list = WordList(name: "默认单词本")
            modelContext.insert(list)
            selectedList = list
            seedSampleData(in: list)
        } else {
            ensureSelection()
        }
    }

    private func ensureSelection() {
        if selectedList == nil {
            selectedList = lists.first
        }
    }

    private func selectList(_ list: WordList) {
        selectedList = list
        list.touchUsage()
    }

    private func seedSampleData(in list: WordList) {
        let examples = [
            ("serendipity", "[ˌserənˈdɪpəti]", "n.", "意外收获"),
            ("contemplate", "[ˈkɒntəmpleɪt]", "v.", "沉思"),
            ("ubiquitous", "[juːˈbɪkwɪtəs]", "adj.", "无所不在的"),
            ("synergy", "[ˈsɪnərdʒi]", "n.", "协同效应")
        ]
        for item in examples {
            let entry = WordEntry(
                term: item.0,
                pronunciation: item.1,
                partOfSpeech: item.2,
                definition: item.3,
                proficiency: 0,
                list: list
            )
            modelContext.insert(entry)
        }
    }
}

private struct WordListPicker: View {
    let lists: [WordList]
    let selected: WordList?
    let onSelect: (WordList) -> Void

    var body: some View {
        Menu {
            ForEach(lists) { list in
                Button {
                    onSelect(list)
                } label: {
                    Label(list.name, systemImage: "book")
                }
            }
        } label: {
            HStack {
                Text(selected?.name ?? "选择单词本")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.platformBackground))
        }
    }
}

private struct HomeView: View {
    let lists: [WordList]
    @Binding var selectedList: WordList?
    let onSelectList: (WordList) -> Void
    let onStartStudy: () -> Void

    private var dueEntries: [WordEntry] {
        guard let list = selectedList else { return [] }
        return list.entries.filter { $0.proficiency < 90 }
    }

    private var remainingCount: Int {
        let calendar = Calendar.current
        return dueEntries.filter {
            guard let reviewed = $0.lastReviewedAt else { return true }
            return !calendar.isDateInToday(reviewed)
        }.count
    }

    private var totalCount: Int { dueEntries.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(Date.now, format: .dateTime.year().month().day())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("\(remainingCount)/\(totalCount)")
                    .font(.system(size: 48, weight: .bold))
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, alignment: .center)

                WordListPicker(lists: lists, selected: selectedList, onSelect: onSelectList)

                Button(action: onStartStudy) {
                    Text("开始背词")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor))
                        .foregroundColor(.white)
                        .font(.headline)
                }
                .disabled(selectedList == nil || totalCount == 0)
                .opacity((selectedList == nil || totalCount == 0) ? 0.6 : 1.0)

                Spacer(minLength: 32)
            }
            .padding()
        }
        .navigationTitle("首页")
    }
}

private enum WordSort: String, CaseIterable, Identifiable {
    case alphabetical = "字典序"
    case proficiency = "熟练度"
    case modifiedAt = "修改日期"
    case lastReviewed = "最后一次背诵"

    var id: String { rawValue }
}

private struct WordListsView: View {
    let lists: [WordList]
    @Binding var selectedList: WordList?
    let onSelectList: (WordList) -> Void
    @Environment(\.modelContext) private var modelContext

    @State private var sort: WordSort = .alphabetical
    @State private var showNewList = false
    @State private var showEditor = false

    private var sortedEntries: [WordEntry] {
        guard let list = selectedList else { return [] }
        switch sort {
        case .alphabetical:
            return list.entries.sorted { $0.term.localizedCaseInsensitiveCompare($1.term) == .orderedAscending }
        case .proficiency:
            return list.entries.sorted { $0.proficiency > $1.proficiency }
        case .modifiedAt:
            return list.entries.sorted { $0.modifiedAt > $1.modifiedAt }
        case .lastReviewed:
            return list.entries.sorted {
                ($0.lastReviewedAt ?? .distantPast) > ($1.lastReviewedAt ?? .distantPast)
            }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                WordListPicker(lists: lists, selected: selectedList, onSelect: onSelectList)
                Button {
                    showNewList = true
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.platformBackground))
                }
                .accessibilityLabel("新建单词本")
            }
            Picker("排序", selection: $sort) {
                ForEach(WordSort.allCases) { value in
                    Text(value.rawValue).tag(value)
                }
            }
            .pickerStyle(.segmented)

            List {
                ForEach(Array(sortedEntries.enumerated()), id: \.element.id) { pair in
                    let index = pair.offset + 1
                    let entry = pair.element
                    NavigationLink {
                        WordDetailView(entry: entry)
                    } label: {
                        WordRow(index: index, entry: entry)
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if selectedList == nil {
                    ContentUnavailableView("请选择单词本", systemImage: "book")
                } else if sortedEntries.isEmpty {
                    ContentUnavailableView(
                        "没有单词",
                        systemImage: "text.book.closed.fill",
                        description: {
                            Text("点击右下角添加一个词条")
                        }
                    )
                }
            }
        }
        .padding()
        .navigationTitle("单词本")
        .sheet(isPresented: $showNewList) {
            NavigationStack {
                NewListSheet { newList in
                    onSelectList(newList)
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            if let list = selectedList {
                NavigationStack {
                    WordEditorView(wordList: list)
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if selectedList != nil {
                Button {
                    showEditor = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .frame(width: 56, height: 56)
                        .foregroundStyle(.tint)
                        .shadow(radius: 4)
                }
                .padding()
            }
        }
    }
}

private struct WordRow: View {
    let index: Int
    let entry: WordEntry

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .frame(width: 32, alignment: .leading)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.term)
                    .font(.headline)
                if entry.pronunciation.isEmpty == false {
                    Text(entry.pronunciation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(entry.proficiency))%")
                    .font(.subheadline)
                    .foregroundColor(.blue)

                Text(entry.modifiedAt, format: Date.FormatStyle(date: .numeric, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if let last = entry.lastReviewedAt {
                    Text(last, format: Date.FormatStyle(date: .numeric, time: .omitted))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct NewListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name: String = ""
    let onCreate: (WordList) -> Void

    var body: some View {
        Form {
            Section(header: Text("新建单词本")) {
                TextField("名称", text: $name)
            }
        }
        .navigationTitle("新建单词本")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    let list = WordList(name: name.isEmpty ? "新单词本" : name)
                    modelContext.insert(list)
                    onCreate(list)
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

private struct WordDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isEditing = false
    @State private var confirmDelete = false

    let entry: WordEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(entry.term)
                    .font(.system(size: 34, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                if entry.pronunciation.isEmpty == false {
                    Text(entry.pronunciation)
                        .foregroundColor(.secondary)
                }

                if entry.partOfSpeech.isEmpty == false {
                    Text(entry.partOfSpeech)
                        .font(.headline)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("熟练度 \(Int(entry.proficiency))%")
                        Spacer()
                    }
                    Slider(
                        value: Binding(
                            get: { entry.proficiency },
                            set: { newValue in
                                entry.proficiency = newValue
                                entry.modifiedAt = .now
                            }
                        ),
                        in: 0...100,
                        step: 1
                    )
                }

                if entry.definition.isEmpty == false {
                    Text(entry.definition)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let lemma = entry.lemma {
                    Text("原型：\(lemma.term)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if entry.derivatives.isEmpty == false {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("派生词")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        WrapView(items: entry.derivatives.map { $0.term })
                    }
                }

                HStack {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("删除", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                    Button {
                        isEditing = true
                    } label: {
                        Label("修改", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("单词卡")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isEditing = true
                } label: {
                    Text("编辑")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            if let list = entry.list {
                NavigationStack {
                    WordEditorView(wordList: list, entry: entry)
                }
            }
        }
        .alert("删除词条？", isPresented: $confirmDelete) {
            Button("删除", role: .destructive) {
                modelContext.delete(entry)
                dismiss()
            }
            Button("取消", role: .cancel) { }
        }
    }
}

private struct WordEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let wordList: WordList?
    let entry: WordEntry?

    @State private var term: String
    @State private var pronunciation: String
    @State private var partOfSpeech: String
    @State private var definition: String
    @State private var proficiency: Double
    @State private var selectedLemmaID: UUID?
    @State private var selectedDerivatives: Set<UUID>
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case term, pronunciation, partOfSpeech, definition
    }

    init(wordList: WordList?, entry: WordEntry? = nil) {
        self.wordList = wordList
        self.entry = entry
        _term = State(initialValue: entry?.term ?? "")
        _pronunciation = State(initialValue: entry?.pronunciation ?? "")
        _partOfSpeech = State(initialValue: entry?.partOfSpeech ?? "")
        _definition = State(initialValue: entry?.definition ?? "")
        _proficiency = State(initialValue: entry?.proficiency ?? 0)
        _selectedLemmaID = State(initialValue: entry?.lemma?.id)
        _selectedDerivatives = State(initialValue: Set(entry?.derivatives.map { $0.id } ?? []))
    }

    var body: some View {
        Form {
            Section(header: Text("单词信息")) {
                TextField("单词或短语（必填）", text: $term)
                    .submitLabel(.next)
                    .focused($focus, equals: .term)
                    .onSubmit { focus = .pronunciation }

                TextField("发音", text: $pronunciation)
                    .submitLabel(.next)
                    .focused($focus, equals: .pronunciation)
                    .onSubmit { focus = .partOfSpeech }

                TextField("词性", text: $partOfSpeech)
                    .submitLabel(.next)
                    .focused($focus, equals: .partOfSpeech)
                    .onSubmit { focus = .definition }

                TextField("释义", text: $definition, axis: .vertical)
                    .lineLimit(2...4)
                    .submitLabel(.done)
                    .focused($focus, equals: .definition)
                    .onSubmit { focus = nil }
            }

            Section(header: Text("熟练度")) {
                HStack {
                    Text("\(Int(proficiency))%")
                    Slider(value: $proficiency, in: 0...100, step: 1)
                }
            }

            Section(header: Text("关联")) {
                let candidates = (wordList?.entries.filter { $0.id != entry?.id } ?? []).sorted {
                    $0.term.localizedCaseInsensitiveCompare($1.term) == .orderedAscending
                }
                Picker("原型", selection: Binding(
                    get: { selectedLemmaID },
                    set: { selectedLemmaID = $0 }
                )) {
                    Text("无").tag(nil as UUID?)
                    ForEach(candidates) { item in
                        Text(item.term).tag(item.id as UUID?)
                    }
                }

                if candidates.isEmpty == false {
                    ForEach(candidates) { item in
                        Toggle(isOn: Binding(
                            get: { selectedDerivatives.contains(item.id) },
                            set: { isOn in
                                if isOn {
                                    selectedDerivatives.insert(item.id)
                                } else {
                                    selectedDerivatives.remove(item.id)
                                }
                            }
                        )) {
                            Text("派生：\(item.term)")
                        }
                    }
                }
            }
        }
        .navigationTitle(entry == nil ? "新建单词" : "编辑单词")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("✔") { save() }
                    .disabled(term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        guard let list = wordList else {
            dismiss()
            return
        }
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date()

        if let entry {
            entry.term = trimmedTerm
            entry.pronunciation = pronunciation
            entry.partOfSpeech = partOfSpeech
            entry.definition = definition
            entry.proficiency = proficiency
            entry.modifiedAt = now
            applyRelations(to: entry, in: list)
        } else {
            let newEntry = WordEntry(
                term: trimmedTerm,
                pronunciation: pronunciation,
                partOfSpeech: partOfSpeech,
                definition: definition,
                proficiency: proficiency,
                list: list,
                now: now
            )
            modelContext.insert(newEntry)
            applyRelations(to: newEntry, in: list)
        }

        list.markUpdated(at: now)
        dismiss()
    }

    private func applyRelations(to entry: WordEntry, in list: WordList) {
        if let lemmaID = selectedLemmaID,
           let lemma = list.entries.first(where: { $0.id == lemmaID }) {
            entry.setLemma(lemma)
        } else {
            entry.lemma = nil
        }

        let desired = selectedDerivatives
        // clear removed derivatives
        for derivative in entry.derivatives where desired.contains(derivative.id) == false {
            derivative.lemma = nil
        }

        let candidates = list.entries.filter { desired.contains($0.id) }
        for item in candidates {
            entry.addDerivative(item)
        }
    }
}

private struct SettingsView: View {
    let lists: [WordList]
    @Binding var selectedList: WordList?

    var body: some View {
        Form {
            Section(header: Text("当前单词本")) {
                if let list = selectedList {
                    Text(list.name)
                    Text("词条数量：\(list.entries.count)")
                        .foregroundColor(.secondary)
                } else {
                    Text("未选择")
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("数据与同步")) {
                Text("数据基于 Apple ID 的 CloudKit 同步，并保留本地缓存。更新应用时保持现有数据不变。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("个人设置")
    }
}

private enum RecognitionPrompt: CaseIterable {
    case term, definition, pronunciation
}

private enum ChoiceTarget {
    case definition, pronunciation
}

private enum StudyQuestion {
    case recognition(RecognitionPrompt)
    case fillIn
    case multipleChoice(ChoiceTarget, options: [WordEntry])
}

private struct StudySessionView: View {
    @Environment(\.dismiss) private var dismiss
    let list: WordList

    @State private var queue: [WordEntry] = []
    @State private var currentIndex: Int = 0
    @State private var question: StudyQuestion = .recognition(.term)
    @State private var hasScored = false
    @State private var fillInInput = ""
    @State private var fillInChecked = false
    @State private var choiceSelection: WordEntry?
    @State private var showCard = false

    var body: some View {
        VStack(spacing: 16) {
            if queue.isEmpty {
                ContentUnavailableView(
                    "当前单词本都达到熟练标准",
                    systemImage: "checkmark.seal.fill",
                    description: {
                        Button("返回") { dismiss() }
                    }
                )
            } else if let word = currentWord {
                Text("剩余 \(queue.count - currentIndex) / \(queue.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer(minLength: 0)

                studyBody(for: word)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(swipeGesture)
                    .padding()

                Spacer(minLength: 0)

                HStack {
                    Button("上一条") { goPrevious() }
                        .disabled(currentIndex == 0)
                    Spacer()
                    Button("单词卡") { showCard = true }
                    Spacer()
                    Button("跳过") { advanceAfterScoredIfNeeded() }
                }
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            }
        }
        .onAppear { prepareQueue() }
        .sheet(isPresented: $showCard) {
            if let word = currentWord {
                NavigationStack {
                    WordDetailView(entry: word)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("关闭") { showCard = false }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
            }
        }
        .navigationTitle("开始背词")
    }

    private var currentWord: WordEntry? {
        guard queue.indices.contains(currentIndex) else { return nil }
        return queue[currentIndex]
    }

    private func prepareQueue() {
        let due = list.entries.filter { $0.proficiency < 90 }
        queue = due.shuffled()
        currentIndex = 0
        resetQuestionState()
    }

    private func resetQuestionState() {
        hasScored = false
        fillInInput = ""
        fillInChecked = false
        choiceSelection = nil
        buildQuestion()
    }

    private func buildQuestion() {
        guard let word = currentWord else { return }
        let roll = Int.random(in: 0..<100)
        if roll < 34 {
            question = .recognition(randomRecognitionPrompt(for: word))
        } else if roll < 67 {
            question = .fillIn
        } else {
            question = .multipleChoice(randomChoiceTarget(), options: options(for: word))
        }
    }

    private func randomRecognitionPrompt(for word: WordEntry) -> RecognitionPrompt {
        var pool: [RecognitionPrompt] = [.term]
        if word.definition.isEmpty == false { pool.append(.definition) }
        if word.pronunciation.isEmpty == false { pool.append(.pronunciation) }
        return pool.randomElement() ?? .term
    }

    private func randomChoiceTarget() -> ChoiceTarget {
        Int.random(in: 0..<100) < 95 ? .definition : .pronunciation
    }

    private func options(for word: WordEntry) -> [WordEntry] {
        let upcoming = queue.enumerated()
            .filter { $0.offset > currentIndex }
            .map(\.element)
            .filter { $0.id != word.id }

        var pool = upcoming
        if pool.count < 3 {
            let extras = list.entries.filter { candidate in
                candidate.id != word.id && pool.contains(where: { $0.id == candidate.id }) == false
            }
            pool.append(contentsOf: extras)
        }

        let picks = Array(pool.shuffled().prefix(3))
        return (picks + [word]).shuffled()
    }

    @ViewBuilder
    private func studyBody(for word: WordEntry) -> some View {
        switch question {
        case .recognition(let prompt):
            recognitionView(word: word, prompt: prompt)
        case .fillIn:
            fillInView(word: word)
        case .multipleChoice(let target, let opts):
            multipleChoiceView(word: word, target: target, options: opts)
        }
    }

    private func recognitionView(word: WordEntry, prompt: RecognitionPrompt) -> some View {
        VStack(spacing: 28) {
            Text(displayText(for: word, prompt: prompt))
                .font(.system(size: 30, weight: .bold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)

            HStack(spacing: 24) {
                Button {
                    scoreCurrent(delta: 0, advance: true)
                } label: {
                    Label("不认识", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.platformMutedFill))
                }

                Button {
                    scoreCurrent(delta: 5, advance: true)
                } label: {
                    Label("认识", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor))
                        .foregroundColor(.white)
                }
            }
        }
    }

    private func fillInView(word: WordEntry) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(word.definition.isEmpty ? "请输入拼写" : word.definition)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                TextField("输入单词", text: $fillInInput)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit { checkFillIn(for: word) }

                if fillInChecked {
                    let isCorrect = fillInInput.trimmedAndLowercased() == word.term.trimmedAndLowercased()
                    Text(fillInInput)
                        .foregroundColor(isCorrect ? .green : .red)
                    if isCorrect == false {
                        Text(word.term)
                            .foregroundColor(.green)
                    }
                }
            }

            Button {
                checkFillIn(for: word)
            } label: {
                Text(fillInChecked ? "下一题" : "确认")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.platformMutedFill))
            }
        }
    }

    private func multipleChoiceView(word: WordEntry, target: ChoiceTarget, options: [WordEntry]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(questionPrompt(for: word, target: target))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                ForEach(options) { option in
                    Button {
                        choose(option: option, for: word)
                    } label: {
                        Text(option.term)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(choiceTint(option: option, correctID: word.id))
                    .disabled(hasScored)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func displayText(for word: WordEntry, prompt: RecognitionPrompt) -> String {
        switch prompt {
        case .term: return word.term
        case .definition: return word.definition.isEmpty ? word.term : word.definition
        case .pronunciation: return word.pronunciation.isEmpty ? word.term : word.pronunciation
        }
    }

    private func questionPrompt(for word: WordEntry, target: ChoiceTarget) -> String {
        switch target {
        case .definition:
            return word.definition.isEmpty ? "请选择对应的释义" : word.definition
        case .pronunciation:
            return word.pronunciation.isEmpty ? "请选择对应的发音" : word.pronunciation
        }
    }

    private func checkFillIn(for word: WordEntry) {
        if hasScored {
            advanceAfterScoredIfNeeded()
            return
        }

        let isCorrect = fillInInput.trimmedAndLowercased() == word.term.trimmedAndLowercased()
        fillInChecked = true
        scoreCurrent(delta: isCorrect ? 30 : 0, advance: false)
    }

    private func choose(option: WordEntry, for word: WordEntry) {
        guard hasScored == false else { return }
        choiceSelection = option
        let correct = option.id == word.id
        scoreCurrent(delta: correct ? 15 : 0, advance: false)
    }

    private func choiceTint(option: WordEntry, correctID: UUID) -> Color {
        guard hasScored else { return .accentColor }
        if option.id == correctID { return .green }
        if choiceSelection?.id == option.id { return .red }
        return .accentColor
    }

    private func scoreCurrent(delta: Double, advance: Bool) {
        guard let word = currentWord else { return }
        if hasScored == false {
            let now = Date()
            word.lastReviewedAt = now
            word.applyProficiencyDelta(delta)
            word.modifiedAt = now
            hasScored = true
        }
        if advance {
            goNext()
        }
    }

    private func advanceAfterScoredIfNeeded() {
        if hasScored {
            goNext()
        } else {
            scoreCurrent(delta: 0, advance: true)
        }
    }

    private func goNext() {
        guard currentIndex + 1 < queue.count else {
            queue = []
            return
        }
        currentIndex += 1
        resetQuestionState()
    }

    private func goPrevious() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        resetQuestionState()
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                if abs(horizontal) > abs(vertical) {
                    if horizontal > 40 {
                        advanceAfterScoredIfNeeded()
                    } else if horizontal < -40 {
                        goPrevious()
                    }
                } else if vertical < -40 {
                    showCard = true
                }
            }
    }
}

private struct WrapView: View {
    let items: [String]

    var body: some View {
        FlexibleView(
            data: items,
            spacing: 8,
            alignment: .leading
        ) { item in
            Text(item)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.platformBackground))
        }
    }
}

// Adapted lightweight flexible layout for chips.
private struct FlexibleView<Elements: Collection, Content: View>: View where Elements.Element: Hashable {
    let data: Elements
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Elements.Element) -> Content

    var body: some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return GeometryReader { geometry in
            ZStack(alignment: Alignment(horizontal: alignment, vertical: .top)) {
                let array = Array(data)
                ForEach(array, id: \.self) { element in
                    content(element)
                        .padding([.horizontal, .vertical], 4)
                        .alignmentGuide(.leading) { d in
                            if abs(width - d.width) > geometry.size.width {
                                width = 0
                                height -= d.height + spacing
                            }
                            let result = width
                            width -= d.width + spacing
                            return result
                        }
                        .alignmentGuide(.top) { _ in
                            let result = height
                            if element == array.last {
                                width = 0
                                height = 0
                            }
                            return result
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension String {
    func trimmedAndLowercased() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private extension Color {
    static var platformBackground: Color {
#if os(iOS)
        Color(.secondarySystemBackground)
#elseif os(macOS)
        Color(NSColor.windowBackgroundColor)
#else
        Color.secondary.opacity(0.1)
#endif
    }

    static var platformMutedFill: Color {
#if os(iOS)
        Color(.systemGray5)
#elseif os(macOS)
        Color(NSColor.controlBackgroundColor)
#else
        Color.secondary.opacity(0.2)
#endif
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WordList.self, WordEntry.self,
            configurations: config
        )
        let list = WordList(name: "预览单词本")
        container.mainContext.insert(list)
        let entry = WordEntry(term: "serendipity", pronunciation: "[ˌserənˈdɪpəti]", partOfSpeech: "n.", definition: "意外发现美好事物的能力", proficiency: 20, list: list)
        container.mainContext.insert(entry)
        return ContentView()
            .modelContainer(container)
    } catch {
        return Text("预览出错：\\(error.localizedDescription)")
    }
}
