# PR75 AI evaluation: knee rule on

UTC run: 2026-11-18T09:00:52.604931Z; revision: `a9e6cd49f1a54cd70b71c67be2427c13a15edbdf`; modified code: false.
Exact source blobs are recorded in the companion JSON. No MP4s are published.

## Frozen push-up set (unchanged32 cases)

| Metric | Value | Threshold | Result |
|---|---|---|---|
| M1 Count accuracy | 81.0% (51/63) | ≥ 90.0% | fail |
| M2 Rejection rate | 87.4% (181/207) | ≥ 90.0% | fail |
| M3 Right reason | 63.3% (131/207) | ≥ 80.0% | fail |

32 cases. Judged reps with no labelled rep: 0 counted, 5 rejected.

| Group | M1 | M2 | M3 |
|---|---|---|---|
| Position A | 80.0% | 100.0% | 94.3% |
| Position B | 75.0% | 88.1% | 82.1% |
| Position C | – | 78.3% | 52.2% |
| Position D | 82.8% | 91.7% | 19.4% |
| HS | 87.5% | 91.7% | 55.0% |
| HSW | 72.7% | 93.1% | 69.0% |
| JP | 85.7% | 72.9% | 55.9% |
| SWH | 73.3% | 94.9% | 76.3% |

## Iteration4 coordinate set (separate16 cases)

| Group | Confirmed cases | Pending cases | M1 | M2 | M3 |
|---|---:|---:|---:|---:|---:|
| Overall |0|16|N/A|N/A|N/A|
| pushUp |0|8|N/A|N/A|N/A|
| squat |0|8|N/A|N/A|N/A|
| hyunwoo |0|8|N/A|N/A|N/A|
| sangwoo |0|8|N/A|N/A|N/A|

Pending human labels are N/A, not zero accuracy and not a benefit claim.
M2 includes incorrect repetitions with no verdict; explicit rejects, misses and extras are distinct in JSON.
Default remains OFF until all per-rep labels are confirmed and benefit is reviewed.

## Unscored prediction diagnostics

| Case | Exercise | Label status | Accepted events | Rejected events |
|---|---|---|---:|---:|
| 20261118140716241591_normal_gymrats | pushUp | pending |5|1|
| 20261118140732357228_knees_gymrats | pushUp | pending |0|5|
| 20261118140748211269_bent_arms_gymrats | pushUp | pending |0|3|
| 20261118140806566477_belly_gymrats | pushUp | pending |1|4|
| 20261118140831130646_squat_normal_gymrats | squat | pending |1|3|
| 20261118140847280825_squat_shallow_gymrats | squat | pending |0|0|
| 20261118140901505813_squat_not_standing_gymrats | squat | pending |0|3|
| 20261118140919140749_squat_chair_gymrats | squat | pending |0|1|
| 20261118153146739950_normal_gymrats | pushUp | pending |5|0|
| 20261118153203817106_knees_gymrats | pushUp | pending |0|5|
| 20261118153221618003_bent_arms_gymrats | pushUp | pending |0|5|
| 20261118153251158085_belly_gymrats | pushUp | pending |4|1|
| 20261118153318437596_squat_normal_gymrats | squat | pending |5|0|
| 20261118153357549759_squat_shallow_gymrats | squat | pending |0|5|
| 20261118153419912431_squat_not_standing_gymrats | squat | pending |0|5|
| 20261118153457145385_squat_chair_gymrats | squat | pending |5|0|

These event counts are not expected repetition counts. Approach/recovery events may be included unless a human exercise window is provided.
See cases_iter4/README.md for independent label definitions and the agreed depth/full-standing squat criteria.
No physical floor-contact accuracy, live-device performance or new-person generalization is established.
