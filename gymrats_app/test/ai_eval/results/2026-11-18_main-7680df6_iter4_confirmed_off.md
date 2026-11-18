# PR75 AI evaluation: knee rule off

UTC run: 2026-11-18T11:17:59.974701Z; revision: `7680df674060157f23d45341228974a02440de99`; modified code: false.
Exact source blobs are recorded in the companion JSON. No MP4s are published.

## Frozen push-up set (unchanged32 cases)

| Metric | Value | Threshold | Result |
|---|---|---|---|
| M1 Count accuracy | 79.4% (50/63) | ≥ 90.0% | fail |
| M2 Rejection rate | 90.8% (188/207) | ≥ 90.0% | pass |
| M3 Right reason | 59.9% (124/207) | ≥ 80.0% | fail |

32 cases. Judged reps with no labelled rep: 0 counted, 5 rejected.

| Group | M1 | M2 | M3 |
|---|---|---|---|
| Position A | 86.7% | 100.0% | 94.3% |
| Position B | 50.0% | 94.0% | 68.7% |
| Position C | – | 78.3% | 55.1% |
| Position D | 75.9% | 100.0% | 19.4% |
| HS | 87.5% | 98.3% | 55.0% |
| HSW | 81.8% | 79.3% | 58.6% |
| JP | 90.5% | 79.7% | 54.2% |
| SWH | 53.3% | 100.0% | 71.2% |

## Iteration4 coordinate set (separate16 cases)

| Group | Confirmed cases | Pending cases | M1 | M2 | M3 |
|---|---:|---:|---:|---:|---:|
| Overall |16|0|56.7%|84.0%|44.0%|
| pushUp |8|0|60.0%|73.3%|40.0%|
| squat |8|0|55.0%|100.0%|50.0%|
| hyunwoo |8|0|13.3%|88.0%|12.0%|
| sangwoo |8|0|100.0%|80.0%|76.0%|

Pending human labels are N/A, not zero accuracy and not a benefit claim.
M2 includes incorrect repetitions with no verdict; explicit rejects, misses and extras are distinct in JSON.
Default remains OFF until all per-rep labels are confirmed and benefit is reviewed.

## Unscored prediction diagnostics

| Case | Exercise | Label status | Accepted events | Rejected events |
|---|---|---|---:|---:|
| 20261118140716241591_normal_gymrats | pushUp | confirmed |1|5|
| 20261118140732357228_knees_gymrats | pushUp | confirmed |2|3|
| 20261118140748211269_bent_arms_gymrats | pushUp | confirmed |0|3|
| 20261118140806566477_belly_gymrats | pushUp | confirmed |1|4|
| 20261118140831130646_squat_normal_gymrats | squat | confirmed |1|3|
| 20261118140847280825_squat_shallow_gymrats | squat | confirmed |0|0|
| 20261118140901505813_squat_not_standing_gymrats | squat | confirmed |0|3|
| 20261118140919140749_squat_chair_gymrats | squat | confirmed |0|1|
| 20261118153146739950_normal_gymrats | pushUp | confirmed |5|0|
| 20261118153203817106_knees_gymrats | pushUp | confirmed |0|5|
| 20261118153221618003_bent_arms_gymrats | pushUp | confirmed |0|5|
| 20261118153251158085_belly_gymrats | pushUp | confirmed |5|0|
| 20261118153318437596_squat_normal_gymrats | squat | confirmed |5|0|
| 20261118153357549759_squat_shallow_gymrats | squat | confirmed |0|5|
| 20261118153419912431_squat_not_standing_gymrats | squat | confirmed |0|5|
| 20261118153457145385_squat_chair_gymrats | squat | confirmed |5|0|

These event counts are not expected repetition counts. Approach/recovery events may be included unless a human exercise window is provided.
See cases_iter4/README.md for independent label definitions and the agreed depth/full-standing squat criteria.
No physical floor-contact accuracy, live-device performance or new-person generalization is established.
