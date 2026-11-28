# So sánh end-to-end CLI: SPMF (Java), negFIN Baseline và Optimized (Julia).
# Dùng cùng máy, cùng file SPMF, cùng min_sup, mỗi chương trình warm-up 1 lần
# rồi đo 3 lần, lấy median. Bao gồm startup, đọc dữ liệu, khai thác, ghi kết quả.
# Không thay đổi mã nguồn/thuật toán của nhóm.
# Chạy nhanh: julia --project=. scripts/compare_spmf_cli.jl
# Chạy 30 mốc: julia --project=. scripts/compare_spmf_cli.jl --full

using Downloads: download
using Printf: @printf, @sprintf
using Statistics: median

const ROOT = normpath(joinpath(@__DIR__, ".."))
const DATA_DIR = joinpath(ROOT, "data", "benchmark")
const OUT_DIR = joinpath(ROOT, "results", "spmf_comparison")
const JAR = joinpath(ROOT, "spmf", "spmf.jar")
const HF_ROOT = "https://huggingface.co/datasets/stephent9/Lab1_Frequent_Itemset_Mining/resolve/main/"
const CASES = [
    ("Chess", "chess.txt", 0.80),
    ("Mushroom", "mushroom.txt", 0.30),
    ("Accidents", "accidents.txt", 0.70),
    ("Retail", "retail.txt", 0.02),
    ("T10I4D100K", "T10I4D100K.txt", 0.02),
]
const FULL_CONFIGS = [
    ("Chess", "chess.txt", [0.90, 0.85, 0.80, 0.75, 0.70, 0.65]),
    ("Mushroom", "mushroom.txt", [0.40, 0.35, 0.30, 0.25, 0.20, 0.15]),
    ("Accidents", "accidents.txt", [0.75, 0.70, 0.65, 0.60, 0.55, 0.50]),
    ("Retail", "retail.txt", [0.05, 0.03, 0.02, 0.01, 0.005, 0.003]),
    ("T10I4D100K", "T10I4D100K.txt", [0.04, 0.03, 0.02, 0.015, 0.01, 0.007]),
]
const FULL_CASES = [(name, file, Float64(ms)) for (name, file, mslist) in FULL_CONFIGS for ms in mslist]
const REPEATS = 3

include(joinpath(ROOT, "src", "utils.jl"))

function prepare_input(filename::String)
    mkpath(DATA_DIR)
    file = joinpath(DATA_DIR, filename)
    if !isfile(file) || filesize(file) < 1000
        println("Downloading $filename from public Hugging Face dataset ...")
        try
            download(HF_ROOT * filename, file)
        catch err
            error("Không thể tải $filename. Đặt thủ công dữ liệu SPMF vào data/benchmark/. Chi tiết: $err")
        end
    end
    return file
end

function build_command(engine::Symbol, input::String, output::String, minsup::Float64)
    if engine == :spmf
        percent = @sprintf("%.6f%%", 100 * minsup)
        return `java -jar $JAR run NegFIN $input $output $percent`
    end
    algo = engine == :baseline ? "baseline" : "optimized"
    mainfile = joinpath(ROOT, "src", "main.jl")
    julia_cmd = Base.julia_cmd()
    return `$julia_cmd --startup-file=no --project=$ROOT $mainfile --input $input --output $output --minsup $minsup --algo $algo`
end

function once(engine::Symbol, input::String, minsup::Float64)
    out = tempname() * ".spmf"
    try
        cmd = build_command(engine, input, out, minsup)
        started = time_ns()
        run(pipeline(cmd; stdout=devnull))
        elapsed = (time_ns() - started) / 1.0e9
        isfile(out) || error("$engine không xuất file kết quả SPMF")
        result = read_spmf_results(out)
        isempty(result) && error("$engine trả kết quả rỗng bất thường")
        return elapsed, result
    finally
        isfile(out) && rm(out)
    end
end

function measure(engine::Symbol, input::String, minsup::Float64)
    _, reference = once(engine, input, minsup) # warm-up process (not timed)
    times = Float64[]
    for _ in 1:REPEATS
        elapsed, result = once(engine, input, minsup)
        ok, detail = compare_results(reference, result)
        ok || error("$engine không nhất quán giữa các lần chạy: $detail")
        push!(times, elapsed)
    end
    return median(times), reference
end

function escape_svg(s::AbstractString)
    return replace(s, "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", "\"" => "&quot;")
end

# Mỗi dataset một panel, thang thời gian riêng. Không có dữ liệu bịa đặt.
function render_svg(rows)
    width, height = 1160, 790
    colors = ("#627B9D", "#C68A5B", "#498977")
    engines = ("SPMF (Java)", "Julia Baseline", "Julia Optimized")
    open(joinpath(OUT_DIR, "spmf_cli_comparison.svg"), "w") do io
        println(io, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"$width\" height=\"$height\" viewBox=\"0 0 $width $height\">")
        println(io, "<rect width=\"100%\" height=\"100%\" fill=\"white\"/>")
        println(io, "<text x=\"34\" y=\"40\" font-size=\"24\" font-family=\"Arial\" font-weight=\"bold\">SPMF vs Julia negFIN — CLI wall-clock (median of 3)</text>")
        println(io, "<text x=\"34\" y=\"65\" font-size=\"13\" font-family=\"Arial\" fill=\"#555\">Includes process startup, input parsing and output writing. Bars scaled within each dataset.</text>")
        for (index, row) in enumerate(rows)
            panel_x = 34 + ((index - 1) % 2) * 560
            panel_y = 100 + div(index - 1, 2) * 214
            vals = (row.spmf, row.baseline, row.optimized)
            xmax = maximum(vals) * 1.15
            println(io, "<rect x=\"$panel_x\" y=\"$panel_y\" width=\"535\" height=\"198\" rx=\"8\" fill=\"#FAFAFA\" stroke=\"#DDDDDD\"/>")
            label = escape_svg(@sprintf("%s — min_sup = %.1f%%", row.dataset, row.minsup * 100))
            println(io, "<text x=\"$(panel_x+14)\" y=\"$(panel_y+25)\" font-size=\"17\" font-family=\"Arial\" font-weight=\"bold\">$label</text>")
            for j in 1:3
                yy = panel_y + 37 + j * 37
                bw = round(Int, vals[j] / xmax * 235)
                value_label = @sprintf("%.3f s", vals[j])
                println(io, "<text x=\"$(panel_x+12)\" y=\"$(yy+16)\" font-size=\"12\" font-family=\"Arial\">$(engines[j])</text>")
                println(io, "<rect x=\"$(panel_x+155)\" y=\"$yy\" width=\"$bw\" height=\"21\" fill=\"$(colors[j])\" rx=\"3\"/>")
                println(io, "<text x=\"$(panel_x+165+bw)\" y=\"$(yy+16)\" font-size=\"12\" font-family=\"Arial\">$value_label</text>")
            end
        end
        println(io, "<text x=\"34\" y=\"762\" font-size=\"12\" font-family=\"Arial\" fill=\"#555\">Note: CLI wall-clock measures deployment overhead, not isolated FIM kernel performance.</text>")
        println(io, "</svg>")
    end
end


# Một biểu đồ đường/benchmark với 3 đường thời gian khi chạy tùy chọn --full.
function render_line_charts(rows)
    colors = ("#627B9D", "#C68A5B", "#498977")
    labels = ("SPMF", "Baseline", "Optimized")
    for (name, _, _) in FULL_CONFIGS
        subset = sort(filter(row -> row.dataset == name, rows); by=row -> row.minsup)
        isempty(subset) && continue
        xmin = minimum(row.minsup for row in subset)
        xmax = maximum(row.minsup for row in subset)
        ymax = maximum(max(row.spmf, row.baseline, row.optimized) for row in subset) * 1.13
        left, right, top, bottom = 90, 920, 85, 490
        mapx(x) = left + (x - xmin) / max(xmax - xmin, 1e-9) * (right - left)
        mapy(y) = bottom - (y / max(ymax, 1e-9)) * (bottom - top)
        target = joinpath(OUT_DIR, "runtime_" * lowercase(name) * ".svg")
        open(target, "w") do io
            println(io, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1000\" height=\"560\" viewBox=\"0 0 1000 560\">")
            println(io, "<rect width=\"100%\" height=\"100%\" fill=\"white\"/>")
            println(io, "<text x=\"70\" y=\"35\" font-family=\"Arial\" font-size=\"22\" font-weight=\"bold\">$(escape_svg(name)): Runtime vs MinSup (CLI)</text>")
            println(io, "<line x1=\"$left\" y1=\"$top\" x2=\"$left\" y2=\"$bottom\" stroke=\"#555\"/>")
            println(io, "<line x1=\"$left\" y1=\"$bottom\" x2=\"$right\" y2=\"$bottom\" stroke=\"#555\"/>")
            for k in 0:4
                yval = ymax*k/4
                yy = mapy(yval)
                println(io, "<line x1=\"$left\" y1=\"$yy\" x2=\"$right\" y2=\"$yy\" stroke=\"#eee\"/>")
                println(io, "<text x=\"$(left-8)\" y=\"$(yy+4)\" font-family=\"Arial\" font-size=\"11\" text-anchor=\"end\">$(@sprintf("%.2f",yval))</text>")
            end
            for row in subset
                xx = mapx(row.minsup)
                println(io, "<text x=\"$xx\" y=\"510\" font-family=\"Arial\" font-size=\"11\" text-anchor=\"middle\">$(@sprintf("%.1f", row.minsup*100))</text>")
            end
            for k in 1:3
                values = [k==1 ? row.spmf : k==2 ? row.baseline : row.optimized for row in subset]
                path = join([@sprintf("%.1f,%.1f",mapx(row.minsup),mapy(values[i])) for (i,row) in enumerate(subset)], " ")
                println(io, "<polyline fill=\"none\" stroke=\"$(colors[k])\" stroke-width=\"3\" points=\"$path\"/>")
                for (i,row) in enumerate(subset)
                    println(io, "<circle cx=\"$(mapx(row.minsup))\" cy=\"$(mapy(values[i]))\" r=\"4\" fill=\"$(colors[k])\"/>")
                end
                lx = 110 + 230*(k-1)
                println(io, "<line x1=\"$lx\" y1=\"50\" x2=\"$(lx+24)\" y2=\"50\" stroke=\"$(colors[k])\" stroke-width=\"3\"/>")
                println(io, "<text x=\"$(lx+32)\" y=\"54\" font-family=\"Arial\" font-size=\"13\">$(labels[k])</text>")
            end
            println(io, "<text x=\"510\" y=\"540\" font-family=\"Arial\" font-size=\"13\" text-anchor=\"middle\">Minimum Support (%)</text>")
            println(io, "<text x=\"25\" y=\"300\" font-family=\"Arial\" font-size=\"13\" transform=\"rotate(-90 25 300)\" text-anchor=\"middle\">Wall-clock (seconds)</text>")
            println(io, "</svg>")
        end
    end
end

function main()
    isfile(JAR) || error("Thiếu $JAR. Chép spmf.jar vào thư mục spmf/ trước khi chạy.")
    Sys.which("java") === nothing && error("Không tìm thấy Java trong PATH.")
    mkpath(OUT_DIR)
    println("=== Benchmark cùng máy / cùng file / cùng min_sup ===")
    println("Julia: ", VERSION, " | CPU: ", Sys.CPU_NAME, " | OS: ", Sys.KERNEL)
    println("Java: ", first(split(strip(read(`java --version`, String)), '\n')))
    println("Metric: end-to-end process wall-clock, median of $REPEATS measurements (1 warm-up).")
    results = NamedTuple[]
    cases = "--full" in ARGS ? FULL_CASES : CASES
    println("Points: ", length(cases), " (use --full for all 30 points)")
    for (name, file, minsup) in cases
        input = prepare_input(file)
        transactions = read_spmf_database(input)
        println("\nDataset: $name | transactions=$(length(transactions)) | minsup=$(minsup*100)%")
        t_spmf, s = measure(:spmf, input, minsup)
        t_base, b = measure(:baseline, input, minsup)
        t_opt, o = measure(:optimized, input, minsup)
        a, detail_a = compare_results(s, b)
        c, detail_c = compare_results(s, o)
        (a && c) || error("Kết quả không khớp trên $name: $detail_a; $detail_c")
        @printf("  SPMF=%.3fs | Baseline=%.3fs | Optimized=%.3fs | MATCH 100%% (%d itemsets)\n", t_spmf, t_base, t_opt, length(s))
        push!(results, (dataset=name, minsup=minsup, tx=length(transactions), itemsets=length(s), spmf=t_spmf, baseline=t_base, optimized=t_opt))
    end
    csv = joinpath(OUT_DIR, "spmf_cli_comparison.csv")
    open(csv, "w") do io
        println(io, "dataset,minsup,transactions,itemsets,time_spmf_s,time_baseline_s,time_optimized_s,match")
        for row in results
            @printf(io, "%s,%.4f,%d,%d,%.6f,%.6f,%.6f,MATCH_100%%\n", row.dataset, row.minsup, row.tx, row.itemsets, row.spmf, row.baseline, row.optimized)
        end
    end
    open(joinpath(OUT_DIR, "benchmark_environment.txt"), "w") do io
        println(io, "Julia: ", VERSION)
        println(io, "Operating system: ", Sys.KERNEL, " / ", Sys.MACHINE)
        println(io, "CPU: ", Sys.CPU_NAME)
        println(io, "Logical Julia threads: ", Threads.nthreads())
        println(io, "Java: ", first(split(strip(read(`java --version`, String)), '\n')))
        println(io, "Measurement: CLI end-to-end wall clock; 1 warm-up, 3 repeats, median. Includes startup, parsing and output.")
    end
    summary_rows = [first(filter(row -> row.dataset == name, results)) for (name, _, _) in CASES]
    render_svg(summary_rows)
    if "--full" in ARGS
        render_line_charts(results)
    end
    println("\n[DONE] Bảng CSV + biểu đồ SVG + môi trường đo: $OUT_DIR")
end

main()
