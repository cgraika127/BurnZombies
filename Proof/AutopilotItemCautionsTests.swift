import BurnCore
import Foundation

/// The full item list names the same risks as the policy, including evidence it couldn't check.
func itemCautionsProof() {
  func item(_ kind: AutopilotKind, _ facts: [String: String]) -> AutopilotItem {
    AutopilotItem(id: kind.rawValue + ":fixture", kind: kind, name: "Fixture", facts: facts)
  }

  for changes in ["small", "large"] {
    let copy = item(.worktree, ["saved": "local", "changes": changes, "inUse": "no"])
    equal(
      AutopilotPolicy.itemCautions(copy), ["work only on this Mac", "unsaved changes"],
      "local work and \(changes) changes are both named")
  }

  let server = item(.process, ["listening": "yes", "idle": "1h"])
  equal(
    AutopilotPolicy.itemCautions(server), ["a running server"], "a server is not a safe program")

  for fact in ["saved", "changes", "inUse"] {
    var facts = ["saved": "merged", "changes": "none", "inUse": "no"]
    facts[fact] = "unknown"
    equal(
      AutopilotPolicy.itemCautions(item(.worktree, facts)), ["things I couldn't check"],
      "unknown \(fact) stays visible")
  }
  equal(
    AutopilotPolicy.itemCautions(item(.process, ["listening": "unknown", "idle": "1h"])),
    ["things I couldn't check"], "an unchecked port stays visible")

  equal(
    AutopilotPolicy.itemCautions(
      item(.worktree, ["saved": "unknown", "changes": "unknown", "inUse": "unknown"])),
    ["things I couldn't check"], "multiple unchecked facts share one caution")
  equal(
    AutopilotPolicy.itemCautions(
      item(.worktree, ["saved": "local", "changes": "small", "inUse": "unknown"])),
    ["work only on this Mac", "unsaved changes", "things I couldn't check"],
    "known and unchecked risks keep the policy's stable order")

  for saved in ["pushed", "merged"] {
    equal(
      AutopilotPolicy.itemCautions(
        item(.worktree, ["saved": saved, "changes": "none", "inUse": "no", "stale": "week"])),
      [], "a safe \(saved) copy has no caution")
  }
  equal(
    AutopilotPolicy.itemCautions(item(.process, ["listening": "no", "idle": "1h"])), [],
    "a quiet program with a checked closed port has no caution")
  equal(
    AutopilotPolicy.itemCautions(item(.disk, ["folder": "package-cache", "stale": "week"])), [],
    "an old rebuildable folder has no caution")
}
