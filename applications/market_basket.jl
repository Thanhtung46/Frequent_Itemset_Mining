# Application 1: real Groceries transactions -> negFIN -> association rules.
# All computation is Julia. Groceries data source is documented in docs/Chapter3_notes.md.
const GROCERIES_URL = "https://raw.githubusercontent.com/Elthiero/association-rule-learning-groceries/main/data/groceries.csv"

function load_baskets(path::AbstractString)::Vector{Vector{String}}
    isfile(path) || error("Missing Groceries data file: $path")
    baskets = Vector{Vector{String}}()
    for line in eachline(path)
        # This particular Groceries CSV contains unquoted comma-separated item names.
        names = String[]
        for token in split(replace(line, '\ufeff' => ""), ',')
            name = strip(replace(strip(token), "\"" => ""))
            isempty(name) || push!(names, name)
        end
        isempty(names) || push!(baskets, sort!(unique(names)))
    end
    isempty(baskets) && error("Groceries contains no valid transactions")
    return baskets
end

function encode_baskets(baskets::Vector{Vector{String}})
    vocab = sort!(unique(vcat(baskets...)))
    names_to_id = Dict(name => i for (i, name) in enumerate(vocab))
    txs = [sort!([names_to_id[name] for name in basket]) for basket in baskets]
    return txs, vocab
end

struct AssociationRule
    lhs::Vector{Int}
    rhs::Vector{Int}
    count::Int
    support::Float64
    confidence::Float64
    lift::Float64
    leverage::Float64
end

function association_rules(itemsets::ItemsetSupport, n::Int;
                           minconf::Float64=0.15, minsup::Float64=0.01)::Vector{AssociationRule}
    n > 0 || error("Number of transactions must be positive")
    0.0 <= minconf <= 1.0 || error("minconf must be between 0 and 1")
    0.0 < minsup <= 1.0 || error("minsup must be in (0, 1]")
    result = AssociationRule[]
    for (combined, count_ab) in itemsets
        k = length(combined)
        k < 2 && continue
        count_ab / n < minsup && continue
        k <= 20 || error("Itemset too long for exhaustive rule enumeration: $k")
        for mask in 1:((1 << k) - 2)
            lhs = Int[combined[i] for i in 1:k if mask & (1 << (i-1)) != 0]
            rhs = Int[combined[i] for i in 1:k if mask & (1 << (i-1)) == 0]
            support_lhs = get(itemsets, Tuple(lhs), 0)
            support_rhs = get(itemsets, Tuple(rhs), 0)
            (support_lhs > 0 && support_rhs > 0) ||
                error("negFIN result missing subset support for $(combined)")
            confidence = count_ab / support_lhs
            confidence + 1e-12 < minconf && continue
            support = count_ab / n
            lift = confidence / (support_rhs / n)
            leverage = support - (support_lhs / n) * (support_rhs / n)
            push!(result, AssociationRule(lhs, rhs, count_ab, support, confidence, lift, leverage))
        end
    end
    sort!(result; by=r -> (-r.lift, -r.confidence, -r.count,
                          join(r.lhs, ":"), join(r.rhs, ":")))
    return result
end

function describe_rule(rule::AssociationRule, vocabulary::Vector{String})
    left = join([vocabulary[i] for i in rule.lhs], " + ")
    right = join([vocabulary[i] for i in rule.rhs], " + ")
    return "[$left] => [$right]: confidence=$(@sprintf("%.1f", rule.confidence*100))%, " *
           "lift=$(@sprintf("%.2f", rule.lift)). " *
           "Goi y thu nghiem ban kem; chi la tuong quan, khong chung minh quan he nhan qua."
end

function run_market_basket(; csv_path::String=joinpath(ROOT, "data", "chapter3", "groceries.csv"),
                           minsup::Float64=0.01, minconf::Float64=0.15,
                           algo::Symbol=:baseline, download_if_missing::Bool=true,
                           output_dir::String=joinpath(ROOT, "results", "chapter3", "market_basket"))
    if !isfile(csv_path)
        download_if_missing || error("Missing $csv_path. Download Groceries CSV first.")
        mkpath(dirname(csv_path))
        println("Downloading real Groceries CSV from: $GROCERIES_URL")
        try
            Downloads.download(GROCERIES_URL, csv_path)
        catch err
            error("Groceries download failed. Download $GROCERIES_URL to $csv_path. Detail: $err")
        end
    end
    baskets = load_baskets(csv_path)
    txs, vocabulary = encode_baskets(baskets)
    mkpath(output_dir)
    save_transactions(joinpath(output_dir, "transactions.spmf"), txs)
    write_csv(joinpath(output_dir, "item_mapping.csv"), ["item_id", "item_name"],
              ((i, name) for (i, name) in enumerate(vocabulary)))

    began = time()
    itemsets = mine_itemsets(txs, minsup; algo=algo,
                             output=joinpath(output_dir, "frequent_itemsets.spmf"))
    elapsed = time() - began
    validate_support(txs, itemsets) || error("Support validation failed")
    rules = association_rules(itemsets, length(txs); minconf=minconf, minsup=minsup)
    named_items(ids) = join((vocabulary[i] for i in ids), " + ")
    columns = ["antecedent", "consequent", "support_count", "support", "confidence", "lift", "leverage"]
    rows = [(named_items(r.lhs), named_items(r.rhs), r.count,
             @sprintf("%.8f", r.support), @sprintf("%.8f", r.confidence),
             @sprintf("%.8f", r.lift), @sprintf("%.8f", r.leverage)) for r in rules]
    write_csv(joinpath(output_dir, "association_rules.csv"), columns, rows)
    write_csv(joinpath(output_dir, "top10_lift.csv"), columns, first(rows, min(10, length(rows))))
    top = first(rules, min(10, length(rules)))
    save_horizontal_bars_svg(joinpath(output_dir, "top10_lift.svg"),
        [named_items(r.lhs) * " => " * named_items(r.rhs) for r in top],
        [r.lift for r in top], "Groceries: Top 10 association rules by Lift"; xlabel="Lift")
    open(joinpath(output_dir, "summary.txt"), "w") do io
        println(io, "Source: $csv_path")
        println(io, "Transactions: $(length(txs)); products: $(length(vocabulary))")
        println(io, "Algorithm: $algo; minsup: $minsup; minconf: $minconf")
        println(io, "Frequent itemsets: $(length(itemsets)); association rules: $(length(rules))")
        println(io, "Mining elapsed_sec: $(@sprintf("%.4f", elapsed))")
        println(io, "Support cross-check: PASS")
        for (i, rule) in enumerate(first(rules, min(3, length(rules))))
            println(io, "Top $i: ", describe_rule(rule, vocabulary))
        end
    end
    println("MARKET: $(length(txs)) transactions; $(length(itemsets)) itemsets; " *
            "$(length(rules)) rules; support PASS; $(@sprintf("%.3f", elapsed)) sec")
    for r in first(rules, min(3, length(rules)))
        println("  ", describe_rule(r, vocabulary))
    end
    println("Output: $output_dir")
    return (; transactions=length(txs), itemsets=length(itemsets), rules=rules,
            vocabulary=vocabulary, output_dir=output_dir)
end
