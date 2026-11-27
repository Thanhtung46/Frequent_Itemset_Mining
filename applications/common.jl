# Shared Julia-only I/O helpers and a direct call into the team's negFIN.
const ItemsetSupport = Dict{Tuple{Vararg{Int}}, Int}

function save_transactions(path::AbstractString, txs::Vector{Vector{Int}})
    mkpath(dirname(path))
    open(path, "w") do io
        for tx in txs
            isempty(tx) && error("Empty transactions are not supported")
            items = sort!(unique(tx))
            all(>(0), items) || error("Transaction items must be positive integers")
            println(io, join(items, ' '))
        end
    end
    return path
end

function mine_itemsets(txs::Vector{Vector{Int}}, minsup::Real;
                       algo::Symbol=:baseline, output::Union{Nothing, String}=nothing)::ItemsetSupport
    isempty(txs) && error("Cannot mine an empty transaction database")
    isfinite(minsup) && minsup > 0 || error("minsup must be finite and > 0")
    (minsup <= 1 || isinteger(minsup)) || error("Absolute minsup must be an integer")
    algo in (:baseline, :optimized) || error("algo must be :baseline or :optimized")
    clean = [sort!(unique(copy(tx))) for tx in txs]
    all(tx -> !isempty(tx) && all(>(0), tx), clean) || error("Invalid transaction")
    raw = algo == :baseline ? negfin_baseline(clean, minsup) : negfin_optimized(clean, minsup)
    threshold = resolve_min_sup_count(length(clean), minsup)
    result = ItemsetSupport()
    for (items, support) in raw
        key = Tuple(sort!(unique(copy(items))))
        isempty(key) && error("negFIN emitted an empty itemset")
        support >= threshold || error("negFIN support below threshold for $(key)")
        haskey(result, key) && error("negFIN emitted duplicate itemset $(key)")
        result[key] = support
    end
    if output !== nothing
        mkpath(dirname(output))
        sorted_items = sort!(collect(result); by=entry -> (length(entry.first), entry.first))
        write_spmf_results(output, [(collect(k), v) for (k, v) in sorted_items])
    end
    return result
end

function validate_support(txs::Vector{Vector{Int}}, itemsets::ItemsetSupport)
    sets = [Set(tx) for tx in txs]
    for (items, expected) in itemsets
        observed = count(tx -> all(in(tx), items), sets)
        observed == expected || error("Wrong support for $items: got $expected, expected $observed")
    end
    return true
end

function csv_field(value)::String
    s = string(value)
    if occursin(',', s) || occursin('"', s) || occursin('\n', s)
        return "\"" * replace(s, "\"" => "\"\"") * "\""
    end
    return s
end

function write_csv(path::AbstractString, headers::Vector{String}, rows)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, join(csv_field.(headers), ','))
        for row in rows
            println(io, join(csv_field.(collect(row)), ','))
        end
    end
    return path
end

function svg_escape(s)::String
    replace(string(s), '&' => "&amp;", '<' => "&lt;", '>' => "&gt;", '"' => "&quot;")
end

function save_horizontal_bars_svg(path::AbstractString, labels::Vector{String}, vals::Vector{Float64},
                                  title::String; xlabel::String="Value")
    length(labels) == length(vals) || error("Labels and values mismatch")
    n = length(vals)
    width, left, barwidth, rowheight = 1140, 490, 530, 38
    height = max(220, 120 + n * rowheight)
    maximum_val = isempty(vals) ? 1.0 : max(maximum(vals), eps())
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"$width\" height=\"$height\" viewBox=\"0 0 $width $height\">")
        println(io, "<rect width=\"100%\" height=\"100%\" fill=\"white\"/>")
        println(io, "<text x=\"25\" y=\"36\" font-family=\"Arial\" font-size=\"22\" font-weight=\"bold\">$(svg_escape(title))</text>")
        for i in 1:n
            y = 70 + (i-1)*rowheight
            bar = round(Int, vals[i] / maximum_val * barwidth)
            println(io, "<text x=\"$(left-10)\" y=\"$(y+21)\" text-anchor=\"end\" font-family=\"Arial\" font-size=\"13\">$(svg_escape(labels[i]))</text>")
            println(io, "<rect x=\"$left\" y=\"$y\" height=\"25\" width=\"$bar\" rx=\"3\" fill=\"#3366a6\"/>")
            println(io, "<text x=\"$(left+bar+8)\" y=\"$(y+19)\" font-family=\"Arial\" font-size=\"13\">$(@sprintf("%.3f", vals[i]))</text>")
        end
        println(io, "<text x=\"$left\" y=\"$(height-16)\" font-family=\"Arial\" font-size=\"14\">$(svg_escape(xlabel))</text>")
        println(io, "</svg>")
    end
    return path
end

function parse_kv_args(args::Vector{String}, defaults::Dict{String, String})
    options = copy(defaults)
    i = 1
    while i <= length(args)
        key = args[i]
        haskey(options, key) || error("Unknown argument $key; expected $(join(sort!(collect(keys(options))), ", "))")
        i < length(args) || error("Missing value for $key")
        options[key] = args[i + 1]
        i += 2
    end
    return options
end
