"""
Entry-point dòng lệnh (CLI) cho thuật toán `negFIN`.
Ví dụ:
    julia --project=. src/main.jl --input data/toy/sample.txt --output out.txt --minsup 0.4
    julia --project=. src/main.jl --input data.txt --output out.txt --minsup 0.05 --algo optimized --stats
"""

using Printf: @printf

include("utils.jl")
include("structures.jl")
include("negfin_baseline.jl")
include("negfin_optimized.jl")

"""
    parse_cli_args(args::Vector{String}) -> NamedTuple

Phân tích tham số dòng lệnh cho `negFIN` CLI.
"""
function parse_cli_args(args::Vector{String})
    input_path = ""
    output_path = ""
    minsup_str = ""
    algo = "optimized"
    show_stats = false

    idx = 1
    while idx <= length(args)
        arg = args[idx]
        if arg == "--input" || arg == "-i"
            idx += 1
            input_path = args[idx]
        elseif arg == "--output" || arg == "-o"
            idx += 1
            output_path = args[idx]
        elseif arg == "--minsup" || arg == "-m"
            idx += 1
            minsup_str = args[idx]
        elseif arg == "--algo" || arg == "-a"
            idx += 1
            algo = lowercase(args[idx])
        elseif arg == "--stats"
            show_stats = true
        elseif arg == "--help" || arg == "-h"
            println(
                """
                Cách dùng:
                  julia --project=. src/main.jl --input <file> --output <file> --minsup <val> [options]

                Tham số bắt buộc:
                  --input,  -i <path>   Đường dẫn file CSDL giao dịch chuẩn SPMF (.txt)
                  --output, -o <path>   Đường dẫn file xuất tập phổ biến chuẩn SPMF (.txt)
                  --minsup, -m <val>    Ngưỡng hỗ trợ tối thiểu (tỷ lệ 0 < val <= 1 hoặc số nguyên)

                Tùy chọn:
                  --algo, -a <name>     Phiên bản thuật toán: optimized (mặc định) | baseline
                  --stats               In thời gian chạy, bộ nhớ cấp phát và số tập phổ biến
                  --help, -h            Hiển thị hướng dẫn
                """,
            )
            exit(0)
        else
            error("Tham số không hợp lệ: $arg (dùng --help để xem hướng dẫn)")
        end
        idx += 1
    end

    if isempty(input_path) || isempty(output_path) || isempty(minsup_str)
        error("Thiếu tham số bắt buộc (--input, --output, --minsup). Dùng --help để xem hướng dẫn.")
    end
    if !(algo in ("baseline", "optimized"))
        error("Giá trị --algo phải là 'baseline' hoặc 'optimized', nhận được: '$algo'")
    end

    min_sup = occursin('.', minsup_str) ? parse(Float64, minsup_str) : parse(Int, minsup_str)
    return (
        input_path=input_path,
        output_path=output_path,
        min_sup=min_sup,
        algo=algo,
        show_stats=show_stats,
    )
end

"""
    run_cli(args::Vector{String})

Thực thi pipeline đọc CSDL SPMF -> chạy `negFIN` -> ghi kết quả chuẩn SPMF.
"""
function run_cli(args::Vector{String})
    cfg = parse_cli_args(args)
    transactions = read_spmf_database(cfg.input_path)

    t_start = time_ns()
    results = if cfg.algo == "baseline"
        negfin_baseline(transactions, cfg.min_sup)
    else
        negfin_optimized(transactions, cfg.min_sup)
    end
    elapsed_sec = (time_ns() - t_start) / 1e9

    write_spmf_results(cfg.output_path, results)

    if cfg.show_stats
        @printf(
            "[negFIN | %s] Transactions: %d | MinSup: %s | Itemsets: %d | Runtime: %.4f s\n",
            cfg.algo,
            length(transactions),
            string(cfg.min_sup),
            length(results),
            elapsed_sec,
        )
    end
    return results
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_cli(ARGS)
end
