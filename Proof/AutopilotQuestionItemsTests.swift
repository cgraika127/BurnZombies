import BurnCore
import Foundation

/// The full list behind a card must have every current match, with its identity and size,
/// without turning a read into an answer or adding things already kept or authorized elsewhere.
func questionItemsProof() {
  func item(
    _ id: String, bytes: UInt64 = 1_000_000_000, kind: AutopilotKind = .worktree,
    repo: String = "demo-api", stale: String = "week", protected: String? = nil
  ) -> AutopilotItem {
    AutopilotItem(
      id: kind.rawValue + ":" + id, kind: kind, name: id,
      path: "/fixture/projects/" + repo + "/" + id, bytes: bytes,
      facts: ["repo": repo, "stale": stale, "saved": "local", "changes": "small"],
      protectedReason: protected)
  }
  func entry(
    _ item: AutopilotItem, _ status: AutopilotStatus = .unsure, authority: String? = nil
  ) -> AutopilotEntry {
    AutopilotEntry(
      item: item, status: status, authority: authority, label: item.name, why: "Fixture",
      consequence: "Fixture")
  }
  var question = AutopilotQuestion(
    kind: .worktree, match: ["repo": ["demo-api"], "stale": ["day"]],
    question: "Burn old copies?", why: "Fixture", examples: ["three", "two", "one"],
    count: 5, bytes: 8_000_000_000)
  let wanted = [
    item("one", stale: "day"), item("two", bytes: 2_000_000_000),
    item("three", bytes: 3_000_000_000, stale: "month"), item("four", stale: "older"),
    item("five"),
  ]
  let input =
    wanted.reversed().map { entry($0) } + [
      entry(item("recent", stale: "today")),
      entry(item("unknown-age", stale: "unknown")),
      entry(item("other-project", repo: "demo-docs")),
      entry(item("other-kind", kind: .disk)),
      entry(item("main", protected: "Main project folder")),
      entry(item("protected"), .protected),
      entry(item("kept"), .keep, authority: "operator"),
      entry(item("already-authorized"), .burn, authority: "rule:fixture"),
      entry(item("already-burned"), .burned),
      entry(item("authorized-failure"), .failed, authority: "rule:fixture"),
    ]
  let before = input
  let questionBefore = question
  let rows = AutopilotPolicy.questionItems(question, entries: input)
  equal(
    rows.map(\.name), ["three", "two", "five", "four", "one"],
    "every match, sorted by size and identity")
  equal(rows.count, question.count, "no three-example limit")
  equal(rows.reduce(0) { $0 + $1.bytes }, question.bytes, "total comes from every listed item")
  equal(Set(rows.map(\.path)), Set(wanted.map(\.path)), "exact paths survive the projection")
  equal(rows.first?.facts["saved"], "local", "the list retains per-item risk evidence")
  equal(input, before, "viewing leaves entries unchanged")
  equal(question, questionBefore, "viewing leaves the question unanswered")

  // A failed operation does not itself settle the underlying question. Its current decision's
  // authority distinguishes an unsure item from one already authorized by a separate rule.
  let failed = entry(item("retry"), .failed)
  equal(
    AutopilotPolicy.questionItems(question, entries: [failed]).map(\.name), ["retry"],
    "an undecided failure stays on the question")

  // The same read works for folders and programs: use each question's kind and full pattern,
  // including widened idle ages, rather than treating every row as a project copy.
  question.kind = .process
  question.match = ["family": ["node"], "idle": ["1h"]]
  let node = AutopilotItem(
    id: "process:node", kind: .process, name: "node", bytes: 150_000_000,
    facts: ["family": "node", "idle": "6h"], pid: 123)
  let python = AutopilotItem(
    id: "process:python", kind: .process, name: "python", bytes: 200_000_000,
    facts: ["family": "python", "idle": "6h"], pid: 124)
  equal(
    AutopilotPolicy.questionItems(
      question, entries: [entry(node), entry(python), entry(wanted[0])]),
    [node], "program family, kind and older idle ages")

  question.kind = .disk
  question.match = ["folder": ["package-cache"], "stale": ["week"]]
  let cache = AutopilotItem(
    id: "disk:cache", kind: .disk, name: "Tool cache", path: "/fixture/cache", bytes: 2_000_000_000,
    facts: ["folder": "package-cache", "stale": "month"])
  equal(
    AutopilotPolicy.questionItems(
      question, entries: [entry(cache), entry(node), entry(wanted[0])]),
    [cache], "folders keep exact path and disk bytes")

  question.answer = .yes
  equal(
    AutopilotPolicy.questionItems(question, entries: [entry(cache)]), [],
    "closed question has no current list")
  question.answer = nil
  equal(
    AutopilotPolicy.questionItems(question, entries: []), [],
    "disappeared matches leave an empty list")
}
