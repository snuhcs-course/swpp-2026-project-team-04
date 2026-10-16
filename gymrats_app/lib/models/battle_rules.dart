/// Length of one battle. Screens show it in seconds, e.g. "60초".
const battleDuration = Duration(seconds: 60);

/// Pace bars and time-axis gaps in one round. A 30 s round is 5 s each.
/// A saved 60 s round stays 10 s each, so the bar and tick count holds.
const battleTimeSlices = 6;
