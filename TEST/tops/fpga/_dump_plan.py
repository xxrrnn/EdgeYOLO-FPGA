import json
from collections import Counter
from pathlib import Path


def dump(name: str, plan_path: str) -> None:
    plan = json.loads(Path(plan_path).read_text())
    print("====", name, "====")
    print("network", plan.get("network"), "mode", plan.get("mode"))
    layers = plan.get("memory_plan", {}).get("layers", [])
    bad = []
    hdr = f"{'layer':40s} acc tiles n*acc in_hw out_hw k cin->cout"
    print(hdr)
    for L in layers:
        acc = int(L.get("acc_depth", 0))
        t = int(L.get("tiles_needed", 0))
        prod = acc * t
        k = L.get("kernel")
        cin = L.get("input_c")
        cout = L.get("output_c")
        mark = " ***" if prod >= 256 else ""
        print(
            f"{L['name']:40s} {acc:3d} {t:2d} {prod:5d} "
            f"{L.get('input_hw')} {L.get('output_hw')} {k} {cin}->{cout}{mark}"
        )
        if prod >= 256:
            bad.append((L["name"], acc, t, prod))
    print("layers with n_tiles*acc_depth>=256:", len(bad))
    ops = plan.get("ops", [])
    print("n_ops", len(ops), "kinds", dict(Counter(o.get("kind") for o in ops)))
    print("--- first 50 ops ---")
    for i, o in enumerate(ops[:50]):
        k = o.get("kind")
        extra = ""
        if k == "cdma_copy":
            extra = f" {o.get('src')} -> {o.get('dst')} n={o.get('length')}"
        elif k in ("dcim_layer", "vpu_exec"):
            extra = f" layer={o.get('layer')}"
        elif k == "cdma_stride":
            extra = (
                f" {o.get('src')} -> {o.get('dst')} "
                f"copy={o.get('copy_bytes')} count={o.get('count')}"
            )
        print(f"{i:3d} {k:16s} {o.get('layer','')}{extra}")
    print()


dump("yolo", r"output/compiled/80832ec_attempt1/yolo_coco_int8/plan.json")
dump("resnet", r"output/compiled/80832ec_attempt1/resnet18_int8/plan.json")
