"""Đào quy ước của gold từ train (P4, D2) -> args/conventions.json (cho máy) + args/gold_conventions.md (cho người).

Mặc định CHỈ dùng train_ids (không dùng dev, để điểm dev không bị rò rỉ). --all: dùng cả dev (cho bản nộp cuối).
  python3 -m eda.mine_conventions [--all]

Bố cục file: nạp dữ liệu -> collect (đếm các thống kê trên gold) -> build_json (kết luận cho máy) -> render_markdown (bản đọc cho người) -> main.
Các luật được đào (khớp phần 1-8 của gold_conventions.md): lệnh ghi đứng sau lệnh đọc nào; ID đọc khi nào; nhóm x-one-of được chọn;
tham số tùy chọn không bao giờ dùng; bộ tham số lệnh đọc; kiểu hỏi lại (sys.ask_missing_info).
"""
import argparse
import json
import re
from collections import Counter, defaultdict
from dataclasses import dataclass, field

from infra import config

PROVIDER_RE = re.compile(r"lấy từ\s+([a-z_]+\.[a-z_]+)")   # mô tả tham số x-ref ghi "lấy từ <tool cung cấp ID>"
ASK = "sys.ask_missing_info"
MIN_CALLS_NEVER_USED = 8       # tool phải có ít nhất từng này call trong gold mới kết luận 'tham số không bao giờ dùng'


def load(use_dev: bool):
    """(các mẫu train, catalog). Mặc định loại các mẫu dev khỏi dữ liệu đào."""
    with open(config.split_dir("train") / "train.jsonl", encoding="utf-8") as f:
        items = [json.loads(l) for l in f if l.strip()]
    if not use_dev:
        dev = set(config.read_ids(config.DEV_IDS))
        items = [i for i in items if i["id"] not in dev]
    with open(config.catalog_path("train"), encoding="utf-8") as f:
        cat = json.load(f)
    return items, cat


@dataclass
class Stats:
    """Các bộ đếm thu được khi duyệt gold (xem `collect`)."""
    n_calls: Counter = field(default_factory=Counter)                          # tool -> số call trong gold
    present: defaultdict = field(default_factory=lambda: defaultdict(Counter))  # tool -> tham số -> số lần xuất hiện
    one_of: defaultdict = field(default_factory=lambda: defaultdict(Counter))   # tool -> nhóm x-one-of được dùng -> số lần
    before_write: defaultdict = field(default_factory=lambda: defaultdict(Counter))  # tool ghi -> tool đọc đứng trước -> số lần
    n_write: Counter = field(default_factory=Counter)                          # tool ghi -> số call
    read_args: defaultdict = field(default_factory=lambda: defaultdict(Counter))     # tool đọc -> bộ khóa tham số -> số lần
    id_rule: Counter = field(default_factory=Counter)                          # (tool cung cấp đã gọi?, ID có trong history?) -> số lệnh ghi
    ask_pat: Counter = field(default_factory=Counter)                          # (tool bị thiếu, tham số thiếu) -> số lần hỏi lại
    ask_prev: defaultdict = field(default_factory=lambda: defaultdict(Counter))      # tool bị thiếu -> tool đứng trước lệnh hỏi
    ask_partial: int = 0                                                       # số lần "làm một phần rồi hỏi" (có lệnh ghi trước lệnh hỏi)
    n_ask: int = 0                                                             # tổng số call hỏi lại


def collect(items, tools, kind, props) -> Stats:
    """Duyệt gold của mọi mẫu và đếm các thống kê. tools/kind/props: định nghĩa, loại read/write và thuộc tính tham số của từng tool."""
    s = Stats()
    for it in items:
        g, res = it["label"]["tool_calls"], it["label"]["tool_results"]
        # toàn bộ kết quả tool trong history (nguồn ID "đã biết" trước khi mẫu bắt đầu)
        hist = " ".join(json.dumps(t.get("tool_results", []), ensure_ascii=False) for t in it["history"] if t["role"] == "assistant")
        for k, c in enumerate(g):
            name, args = c["name"], c["arguments"]
            s.n_calls[name] += 1
            for key in args:
                s.present[name][key] += 1
            groups = tools[name]["parameters"].get("x-one-of")
            if groups:       # gold chỉ dùng MỘT nhóm: ghi nhận nhóm nào
                s.one_of[name][tuple(key for key in args if any(key in grp for grp in groups))] += 1
            if kind[name] == "read":
                s.read_args[name][tuple(sorted(args))] += 1
            if kind[name] == "write":
                s.n_write[name] += 1
                for r in {x["name"] for x in g[:k] if kind[x["name"]] == "read"}:       # các tool đọc đứng trước lệnh ghi này
                    s.before_write[name][r] += 1
                # luật ID: gold đọc tool cung cấp ID khi và chỉ khi ID chưa có trong history
                for key, v in args.items():
                    ref = props[name].get(key, {}).get("x-ref")
                    if ref and isinstance(v, str):
                        m = PROVIDER_RE.search(props[name][key].get("description", ""))
                        prov = m.group(1) if m else None
                        called = any(x["name"] == prov for x in g[:k]) if prov else False
                        s.id_rule[(called, v in hist)] += 1
            if name == ASK:
                s.n_ask += 1
                s.ask_pat[(args.get("tool_name"), tuple(args.get("params", [])))] += 1
                prev = [x["name"] for x in g[:k]]
                s.ask_partial += any(kind[p] == "write" for p in prev)
                for p in set(prev):
                    s.ask_prev[args.get("tool_name")][p] += 1
    return s


def never_used_params(s: Stats, tools, props, kind) -> dict:
    """{tool: [tham số tùy chọn gold không bao giờ dùng]}, chỉ xét tool có >= MIN_CALLS_NEVER_USED call và không thuộc nhóm x-one-of."""
    out = {n: sorted(k for k in props[n] if k not in tools[n]["parameters"].get("required", []) and s.present[n][k] == 0
                     and not any(k in grp for grp in tools[n]["parameters"].get("x-one-of", [])))
           for n in tools if s.n_calls[n] >= MIN_CALLS_NEVER_USED and kind[n] != "meta"}
    return {n: v for n, v in out.items() if v}


def build_json(s: Stats, items, never_used, use_dev: bool) -> dict:
    """Nội dung args/conventions.json (máy đọc)."""
    one_of_pref = {n: [list(k) for k, _ in cn.most_common()] for n, cn in s.one_of.items()}     # nhóm x-one-of theo độ phổ biến
    return {
        "built_from": "train+dev" if use_dev else "train_ids (khong gom dev)",
        "n_samples": len(items),
        "never_used_params": never_used,
        "one_of_preference": one_of_pref,
        "id_rule_consistency": {f"provider_read_called={k[0]},id_in_history={k[1]}": v for k, v in s.id_rule.items()},
        "read_arg_keysets": {r: [[list(k), v] for k, v in cn.most_common(3)] for r, cn in s.read_args.items()},
    }


def render_markdown(s: Stats, items, out: dict, never_used) -> tuple[list[str], int, int]:
    """Các dòng của args/gold_conventions.md (người đọc), cùng (số mẫu nhất quán với luật ID, tổng) để in tóm tắt."""
    L = ["# Quy ước của gold (đào từ train)", "",
         f"Nguồn: `eda/mine_conventions.py`, {len(items)} mẫu ({out['built_from']}). Máy đọc `args/conventions.json`; các luật đánh dấu **[code]** đã được cài trong `args/param_normalizer.py` và `infra/call_gate.py`.", "",
         "## 1. Lệnh ghi → lệnh đọc đứng trước", "",
         "| Tool ghi | Số call | Lệnh đọc đứng trước (tỉ lệ) |", "|---|---|---|"]
    for w, n in s.n_write.most_common(25):
        L.append(f"| `{w}` | {n} | " + ", ".join(f"`{r}` {v / n:.0%}" for r, v in s.before_write[w].most_common(3)) + " |")
    # nhất quán với luật ID: (đã gọi tool cung cấp, ID chưa có trong history) hoặc (chưa gọi, ID đã có trong history)
    ok = s.id_rule[(True, False)] + s.id_rule[(False, True)]
    tot = sum(s.id_rule.values())
    L += ["", "## 2. Quy tắc đọc cho ID (`x-ref`) **[code]**", "",
          "**Gold đọc tool cung cấp ID khi và chỉ khi ID chưa có trong history.** Tool cung cấp được ghi ngay trong mô tả tham số của catalog (\"lấy từ <tool>\"; phủ 68/68 tham số `x-ref` ở train và 61/61 ở public_test), nên luật dùng được cho cả app mới.", "",
          "| Tool cung cấp đã gọi trước trong gold | ID có trong history | Số lệnh ghi |", "|---|---|---|"]
    for (called, inhist), v in sorted(s.id_rule.items(), reverse=True):
        L.append(f"| {'có' if called else 'không'} | {'có' if inhist else 'không'} | {v} |")
    L += ["", f"Nhất quán với luật: {ok}/{tot} = {ok / tot:.1%}. Ngoại lệ ({tot - ok}) nên để nguyên.", "",
          "Gate (**[code]**): trước lệnh ghi, nếu một ID chưa nằm trong history hoặc trong kết quả đọc đã có thì tự chạy tool cung cấp (khi tool đó không có tham số bắt buộc), rồi gắn ID theo tên; nếu vẫn không có ID hợp lệ thì từ chối lệnh ghi và trả lỗi cho LLM (một lần).", "",
          "## 3. Chọn nhóm `x-one-of` **[code]**", "", "Gold luôn chỉ dùng **một** nhóm. Gate bỏ các khóa của nhóm thừa. Tần suất:", ""]
    for n, cn in s.one_of.items():
        L.append(f"- `{n}`: " + ", ".join(f"{'+'.join(k)} ×{v}" for k, v in cn.most_common()))
    L += ["", "## 4. Tham số tùy chọn gold không bao giờ dùng **[code]**", "",
          f"Chỉ xét tool có ≥ {MIN_CALLS_NEVER_USED} call trong gold. Thêm các tham số này thì lệnh không khớp, nên gate bỏ chúng.", ""]
    for n, v in sorted(never_used.items()):
        L.append(f"- `{n}`: " + ", ".join(f"`{x}`" for x in v) + f" (0/{s.n_calls[n]} call)")
    L += ["", "## 5. Bộ tham số của lệnh đọc", "", "| Tool đọc | Bộ khóa tham số phổ biến |", "|---|---|"]
    for r, cn in sorted(s.read_args.items(), key=lambda kv: -sum(kv[1].values()))[:12]:
        L.append(f"| `{r}` | " + "; ".join(f"{list(k) or '{}'} ×{v}" for k, v in cn.most_common(3)) + " |")
    L += ["", "## 6. `sys.ask_missing_info`", "",
          f"{s.n_ask} call hỏi lại; luôn là call cuối. **Làm một phần rồi hỏi** (có lệnh ghi trước đó): {s.ask_partial}/{s.n_ask}.", "",
          "| Tool bị thiếu | Tham số thiếu | Số lần | Lệnh đọc thường đứng trước |", "|---|---|---|---|"]
    for (t, p), v in s.ask_pat.most_common(14):
        prev = ", ".join(f"`{r}`" for r, _ in s.ask_prev[t].most_common(2))
        L.append(f"| `{t}` | {', '.join(p)} | {v} | {prev} |")
    # phần 7-8 là kết luận viết tay từ các script eda khác (eval_time_resolver, eval_fuzzy) và docs/DATA_NOTES.md: không tính tự động
    L += ["", "## 7. Thời gian và văn bản tự do (đo bằng `eda/eval_time_resolver.py`, `eda/eval_fuzzy.py`)", "",
          "- Lịch: `end` − `start` = 60 phút ở 57/61 call (create_event 23/27, update_event 34/36); **dời lịch giữ nguyên độ dài** ở 32/32 mẫu. `tasks.add.due` mặc định 17:00 khi chỉ nói ngày (15/31).",
          "- Thời gian trong gold: 455 giá trị, 59 lấy từ kết quả đọc/history, 396 cần giải từ lời nói. Bộ giải (`args/time_resolver.py`) trùng gold ở 42,7%; thêm \"mốc đã biết ± độ lệch\" (trước/thêm/muộn…) thì với tới 77,5%. Phần còn lại phụ thuộc ngữ cảnh luật không nắm được (\"giờ Lan nói\", \"giờ mới\").",
          "- Văn bản tự do (740 giá trị): chép được từ một đoạn của câu nói (token-F1 > 0,6) ở 53,2%; ít nhất một nguồn (câu, history, kết quả đọc) 61,2%. `ride_hailing.book.dropoff` lấy từ kết quả đọc lịch ở 77%; `pickup` là địa chỉ hồ sơ khi nói \"từ nhà\".", "",
          "## 8. Chưa chắc chắn", "",
          "- Các lệnh đọc **không** phải để lấy ID (vd. `calendar.list_events` trước `ride_hailing.book` 74%, `weather.get_forecast` khi có điều kiện, `ewallet.get_balance` trước `bill_payment.pay` 37%) phụ thuộc nội dung yêu cầu; chưa có luật tất định, để LLM quyết định.",
          "- Tool mới ở public_test không có thống kê (mục 3, 4 không áp dụng); chỉ mục 2 dùng được vì suy từ catalog.",
          "- Chưa rõ vì sao có mẫu gold rỗng dù yêu cầu hợp lệ (vd. `train_0082`); xem `docs/DATA_NOTES.md` mục 12.",
          "- Luật \"tham số tùy chọn không bao giờ dùng\" đúng ở train nhưng trên dev vi phạm 4/156 cơ hội (2,6%); luật gán \"nhà\" → địa chỉ làm đổi 2/3541 call gold. Hai luật này có công tắc (`LIFEMATE_RULES_OFF=never_used,addr`) để đo bằng ablation."]
    L += ["", "## 9. Rà soát D7", "",
          "Xem [gold_conventions_review.md](gold_conventions_review.md) để theo dõi các sửa lỗi D6, nguồn của số liệu và những quy ước cần đo lại."]
    return L, ok, tot


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--all", action="store_true", help="dùng cả dev (cho bản nộp cuối); mặc định chỉ train_ids")
    a = ap.parse_args()
    items, cat = load(a.all)
    tools = {t["name"]: t for app in cat["apps"] for t in app["tools"]}
    kind = {n: t["kind"] for n, t in tools.items()}
    props = {n: t["parameters"].get("properties", {}) for n, t in tools.items()}

    s = collect(items, tools, kind, props)
    never_used = never_used_params(s, tools, props, kind)
    out = build_json(s, items, never_used, a.all)
    (config.REPO / "args" / "conventions.json").write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")

    L, ok, tot = render_markdown(s, items, out, never_used)
    (config.REPO / "args" / "gold_conventions.md").write_text("\n".join(L) + "\n", encoding="utf-8")
    print(f"{len(items)} mau | id_rule nhat quan {ok}/{tot} | tham so khong bao gio dung: {sum(len(v) for v in never_used.values())} (o {len(never_used)} tool)")


if __name__ == "__main__":
    main()
