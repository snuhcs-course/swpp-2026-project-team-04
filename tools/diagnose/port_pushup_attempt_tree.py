"""Render one fitted, evidence-gated attempt tree as Dart in a new candidate file.

The GymRats worktree is read-only. Compare the emitted file with the app
source and replay it against refit-events.jsonl before applying a selected model.
Use only models that retain the small-cycle counter and its stream semantics.
"""
import argparse
import json
import math
import re
from pathlib import Path

NAMES = ("maxDepth", "minElbow", "maxTilt", "bottomHipHandGap", "bottomTorsoDrop",
         "minTorsoDrop", "maxTorsoDrop", "returnElbow", "topHipHandGap",
         "kneeEvidence", "consecutiveKneeFloorEvidence")
MAIN = ("_maxDepth", "_minElbow", "_maxTilt", "_deepHipHandGap", "_deepTorsoDrop",
        "_minTorsoDrop.isFinite ? _minTorsoDrop : null",
        "_maxTorsoDrop.isFinite ? _maxTorsoDrop : null", "_lessArm",
        "_attemptTopHipHand", "_kneesDown() ? 1.0 : 0.0",
        "_kneeFloorFrames >= config.minCheatFrames ? 1.0 : 0.0")
# Independent short attempts do not collect hip extrema or a full-cycle knee
# latch. Only observed evidence is supplied; an unknown is not a measured zero.
SHORT = ("_peakDepth", "_minElbow", "_maxTilt", None, None, None, None,
         "returnElbow", None, "_supported ? 1.0 : null", None)
GATES = {
    "kneesDown": ("kneeEvidence == 1", (9,)),
    "shouldersNotLevel": ("maxTilt != null && maxTilt >= 8 && minElbow != null && minElbow <= 155", (2, 1)),
    "armsStraight": ("minElbow != null && minElbow >= 155 && maxDepth != null && maxDepth >= .5", (1, 0)),
}
HERE = Path(__file__).resolve().parents[2]


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise ValueError(f"Judge source changed at anchor {old!r}; inspect the upstream change")
    return source.replace(old, new, 1)


def branch(nodes, index=0):
    n = nodes[index]
    if "label" in n:
        if n["label"] != "keep" and n["label"] not in GATES:
            raise ValueError(f"Unknown leaf {n}")
        return n["label"]
    feature, threshold = n["feature"], n["threshold"]
    left, right = n["left"], n["right"]
    if not (0 <= feature < len(NAMES) and math.isfinite(threshold)
            and index < left < len(nodes) and index < right < len(nodes)):
        raise ValueError(f"Invalid fitted node {n}")
    a, b = branch(nodes, left), branch(nodes, right)
    # Fixture protection can change entire subtrees to the same verdict.
    return a if a == b else (feature, threshold, a, b)


def render(node, used, indent="  "):
    if isinstance(node, str):
        if node == "keep":
            return [indent + "return original;"]
        guard, fields = GATES[node]
        used.update(fields)
        return [indent + f"return {guard} ? RejectReason.{node} : original;"]
    index, threshold, left, right = node
    used.add(index)
    return [
        indent + f"if (({NAMES[index]} ?? -999) <= {threshold!r}) {{",
        *render(left, used, indent + "  "), indent + "}",
        *render(right, used, indent),
    ]


def invoke(reason, used, args):
    values = [f"{NAMES[i]}: {args[i]}," for i in sorted(used) if args[i] is not None]
    return "_refinePartial(" + reason + ", " + " ".join(values) + ")"


def source_for(source, model, selected):
    if tuple(model["features"]) != NAMES:
        raise ValueError("Unexpected landmark evidence schema")
    prefix, _, base = selected.partition("_")
    if prefix not in {"tree3", "tree5"} or base not in {
        "small30_knees_tilt15", "small30_elev60_knees_tilt15_guarded",
    }:
        raise ValueError("This port supports attempt trees on the two small30 bases only")
    # The current shipping judge already contains the final tree. Restore its
    # two pre-refinement verdict expressions in the new scratch source before
    # rendering another refit; preserve all other counter and visibility logic.
    marker = "\n/// Native ML Kit attempt tree, fitted on the grouped development recordings."
    if marker in source:
        source = source[:source.index(marker)].rstrip() + "\n"
        for spaces, first, old in [
            (4, "reason", "reason"),
            (12, "_supported", "_supported\n                ? RejectReason.kneesDown\n                : _shallowReason(_maxTilt, _minElbow)"),
        ]:
            indent = " " * spaces
            pattern = (r"(?ms)^" + indent + r"reason: _refinePartial\(\s*"
                       + first + r"\b.*?^" + indent + r"\),")
            source, count = re.subn(pattern, indent + "reason: " + old + ",", source)
            if count != 1:
                raise ValueError("Shipping verdict layout changed; specify a reviewed pre-tree --source.")
    if base == "small30_knees_tilt15":
        # Disable only calibration in the temporary candidate. If this base
        # ships, simplify the now-inactive view guard in the final patch.
        source = replace_once(source, "_travelScale = 0.64;", "_travelScale = 1;")
    used = set()
    lines = render(branch(model["trees"][selected]), used)
    if lines == ["  return original;"]:
        return source
    main = invoke("reason", used, MAIN)
    source = replace_once(source, "valid: reason == null,\n    reason: reason,",
                           "valid: reason == null,\n    reason: " + main + ",")
    old_short = "_supported\n                ? RejectReason.kneesDown\n                : _shallowReason(_maxTilt, _minElbow)"
    source = replace_once(source, "reason: " + old_short + ",",
        "reason: " + invoke("_supported ? RejectReason.kneesDown : _shallowReason(_maxTilt, _minElbow)", used, SHORT) + ",")
    if 7 in used:
        source = replace_once(source, "        _nextIndex,\n      );", "        _nextIndex,\n        _lessArm,\n      );")
        source = replace_once(source, "    int index,\n  ) {", "    int index,\n    double? returnElbow,\n  ) {")
    parameters = " ".join(f"double? {NAMES[i]}," for i in sorted(used))
    source += ("\n// Frozen attempt tree " + selected + ". Missing sensors follow the trained missing-value branch.\n"
               + "RejectReason? _refinePartial(RejectReason? original, {" + parameters + "}) {\n"
               + "  if (original != RejectReason.insufficientDepth && original != RejectReason.shouldersNotLevel) return original;\n"
               + "\n".join(lines) + "\n}\n")
    return source


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--trees", required=True, type=Path, help="Fitted feedback-trees.json")
    p.add_argument("--candidate", required=True)
    p.add_argument("--source", type=Path, default=HERE / "gymrats_app/lib/services/pose/rep_judge.dart")
    p.add_argument("--output", required=True, type=Path, help="New scratch Dart file to review/replay")
    args = p.parse_args()
    source = source_for(args.source.read_text(encoding="utf8"), json.loads(args.trees.read_text(encoding="utf8")), args.candidate)
    with args.output.open("x", encoding="utf8") as output:
        output.write(source)


if __name__ == "__main__":
    main()
