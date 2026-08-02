"""Stream-parse Apple Health export.xml and profile heart metrics inside the
user's chosen window: last 2 months, Tue-Sun, 11:30-15:45 local time."""
import json
import sys
from datetime import datetime, time
from xml.etree.ElementTree import iterparse

EXPORT = r"C:\Users\yelen\OneDrive\Desktop\apple_health_export\export.xml"
OUT = sys.argv[1]

SINCE = datetime(2026, 5, 31)
WIN_START = time(11, 30)
WIN_END = time(15, 45)

TYPES = {
    "HKQuantityTypeIdentifierHeartRate": "hr",
    "HKQuantityTypeIdentifierRestingHeartRate": "resting",
    "HKQuantityTypeIdentifierHeartRateVariabilitySDNN": "hrv",
    "HKQuantityTypeIdentifierRespiratoryRate": "resp",
}

hr_sedentary, hr_active, hr_unknown = [], [], []
resting, hrv, resp = [], [], []
days_seen = set()
total_records = 0

def in_window(dt):
    return dt.weekday() != 0 and WIN_START <= dt.time() <= WIN_END  # weekday 0 = Monday

for event, elem in iterparse(EXPORT, events=("end",)):
    if elem.tag != "Record":
        continue
    total_records += 1
    rtype = TYPES.get(elem.get("type"))
    if rtype is None:
        elem.clear()
        continue
    try:
        dt = datetime.strptime(elem.get("startDate")[:19], "%Y-%m-%d %H:%M:%S")
        value = float(elem.get("value"))
    except (TypeError, ValueError):
        elem.clear()
        continue
    if dt < SINCE:
        elem.clear()
        continue

    if rtype == "resting":
        if dt.weekday() != 0:  # daily metric: keep Tue-Sun, ignore clock window
            resting.append(value)
    elif in_window(dt):
        days_seen.add(dt.date().isoformat())
        if rtype == "hr":
            motion = None
            for meta in elem.iter("MetadataEntry"):
                if meta.get("key") == "HKMetadataKeyHeartRateMotionContext":
                    motion = meta.get("value")
            if motion == "1":
                hr_sedentary.append(value)
            elif motion == "2":
                hr_active.append(value)
            else:
                hr_unknown.append(value)
        elif rtype == "hrv":
            hrv.append(value)
        elif rtype == "resp":
            resp.append(value)
    elem.clear()

def stats(values):
    if not values:
        return None
    values = sorted(values)
    n = len(values)
    def pct(p):
        return round(values[min(n - 1, int(n * p / 100))], 1)
    return {
        "n": n,
        "mean": round(sum(values) / n, 1),
        "p10": pct(10), "p25": pct(25), "p50": pct(50),
        "p75": pct(75), "p90": pct(90), "p95": pct(95),
        "min": round(values[0], 1), "max": round(values[-1], 1),
    }

result = {
    "total_records_scanned": total_records,
    "distinct_days_in_window": len(days_seen),
    "hr_sedentary": stats(hr_sedentary),
    "hr_active": stats(hr_active),
    "hr_unknown_context": stats(hr_unknown),
    "resting_hr_daily": stats(resting),
    "hrv_sdnn_ms": stats(hrv),
    "respiratory_rate": stats(resp),
}
with open(OUT, "w") as f:
    json.dump(result, f, indent=2)
print("done")
