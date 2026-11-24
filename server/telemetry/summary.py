"""P6's counting rules over the stored events (P17, P24).

For the tutorial, the pose setup and matching, the starts are the
denominator: each start ends as one of its end event's results, or as
"unobserved" when no end with its attempt_id arrived (the app was closed
mid-way). An end without a start is counted apart and not in the
denominator. battle_finished is already one row per match.
"""

from collections import Counter
from statistics import median

from .models import TelemetryEvent

FLOWS = {
    "tutorial": ("tutorial_started", "tutorial_finished", "duration_ms"),
    "setup": ("setup_started", "setup_finished", "duration_ms"),
    "matching": ("matching_started", "matching_finished", "wait_ms"),
}
UNOBSERVED = "unobserved"


def _times(values):
    return {"mean_ms": round(sum(values) / len(values)), "median_ms": median(values)}


def _flow(events, start, end, time_field):
    starts = {e.attempt_id for e in events if e.event == start}
    ends = {}
    for e in events:
        # One end per attempt: a resend has a new event_id only if the app
        # made a second end by mistake, and the first one counts.
        if e.event == end and e.attempt_id not in ends:
            ends[e.attempt_id] = e
    results = Counter()
    times = {}
    for attempt in starts:
        e = ends.get(attempt)
        result = e.data.get("result") if e else UNOBSERVED
        results[result] += 1
        if e and isinstance(e.data.get(time_field), int):
            times.setdefault(result, []).append(e.data[time_field])
    return {
        "started": len(starts),
        "results": dict(sorted(results.items())),
        "times": {r: _times(v) for r, v in sorted(times.items())},
        "ends_without_start": len(set(ends) - starts),
    }


def summarize(queryset=None):
    """The counts and times of [queryset] (all events by default)."""
    events = list(queryset if queryset is not None else TelemetryEvent.objects.all())
    summary = {
        name: _flow(events, start, end, time_field)
        for name, (start, end, time_field) in FLOWS.items()
    }
    battles = [e for e in events if e.event == "battle_finished"]
    reasons = Counter(e.data.get("end_reason") for e in battles)
    durations = {}
    for e in battles:
        durations.setdefault(e.data.get("end_reason"), []).append(
            e.data.get("duration_ms", 0)
        )
    summary["battle"] = {
        "finished": len(battles),
        "end_reasons": dict(sorted(reasons.items())),
        "times": {r: _times(v) for r, v in sorted(durations.items())},
    }
    return summary
