# Application 2: UCI Digits -> dense gradient descriptors -> Julia k-means
# -> Bag of Visual Words transactions -> the team's negFIN -> pattern enrichment.
# The descriptors are hand-crafted gradients, NOT OpenCV SIFT or ORB.

function read_digits(path::AbstractString; classes::Vector{Int}=[0, 1, 3, 8])
    isfile(path) || error("Missing digits CSV file: $path")
    allowed = Set(classes)
    imgs = Matrix{Float64}[]
    labels = Int[]
    open(path, "r") do io
        for (line_idx, line) in enumerate(eachline(io))
            line_idx == 1 && continue  # label,p0,...,p63
            isempty(strip(line)) && continue
            fields = split(strip(line), ',')
            length(fields) == 65 || error("Digits row $line_idx: expected label + 64 pixels")
            label = parse(Int, fields[1])
            label in allowed || continue
            img = Matrix{Float64}(undef, 8, 8)
            for r in 1:8, c in 1:8
                pixel = parse(Float64, fields[2 + (r - 1)*8 + c - 1])
                0 <= pixel <= 16 || error("Digits row $line_idx: pixel out of range")
                img[r,c] = pixel
            end
            push!(imgs, img)
            push!(labels, label)
        end
    end
    isempty(imgs) && error("No selected Digits images")
    return imgs, labels
end

function split_digits(imgs::Vector{Matrix{Float64}}, labels::Vector{Int};
                      train_fraction::Float64=0.75, max_per_class::Int=150, seed::Int=42)
    length(imgs) == length(labels) || error("Mismatched image/label counts")
    0.0 < train_fraction < 1.0 || error("train_fraction must be between 0 and 1")
    max_per_class >= 3 || error("max_per_class must be >= 3")
    rng = MersenneTwister(seed)
    train_ids, test_ids = Int[], Int[]
    for label in sort!(unique(labels))
        ids = findall(==(label), labels)
        shuffle!(rng, ids)
        resize!(ids, min(length(ids), max_per_class))
        length(ids) >= 3 || error("Not enough samples for class $label")
        n_train = clamp(floor(Int, length(ids) * train_fraction), 1, length(ids)-1)
        append!(train_ids, ids[1:n_train])
        append!(test_ids, ids[n_train+1:end])
    end
    return imgs[train_ids], imgs[test_ids], labels[train_ids], labels[test_ids]
end

function dense_descriptors(image::Matrix{Float64})::Matrix{Float64}
    size(image) == (8, 8) || error("Expected an 8x8 grayscale image")
    # 9 regularly sampled local 3x3 patches, 6 dimensions each.
    # Dimensions: mean intensity, standard deviation, +/- gradient-x/y.
    result = Matrix{Float64}(undef, 9, 6)
    i = 0
    for cy in (2, 4, 6), cx in (2, 4, 6)
        i += 1
        values = Float64[]
        posx = 0.0; negx = 0.0; posy = 0.0; negy = 0.0
        for r in cy-1:cy+1, c in cx-1:cx+1
            push!(values, image[r,c])
            gx = image[r, min(c+1, 8)] - image[r, max(c-1, 1)]
            gy = image[min(r+1, 8), c] - image[max(r-1, 1), c]
            posx += max(gx, 0.0); negx += max(-gx, 0.0)
            posy += max(gy, 0.0); negy += max(-gy, 0.0)
        end
        result[i,1] = mean(values) / 16
        result[i,2] = std(values; corrected=false) / 16
        result[i,3] = posx / 144
        result[i,4] = negx / 144
        result[i,5] = posy / 144
        result[i,6] = negy / 144
    end
    return result
end

function collect_descriptors(images::Vector{Matrix{Float64}})
    isempty(images) && error("No images to describe")
    out = Matrix{Float64}(undef, length(images)*9, 6)
    for (i, image) in enumerate(images)
        out[(i-1)*9+1:i*9,:] = dense_descriptors(image)
    end
    return out
end

@inline function closest_word(features::AbstractMatrix{Float64}, row::Int, centroids::Matrix{Float64})
    k = size(centroids, 1)
    d = size(centroids, 2)
    best, best_distance = 1, Inf
    @inbounds for cluster in 1:k
        distance = 0.0
        for col in 1:d
            delta = features[row,col] - centroids[cluster,col]
            distance += delta*delta
        end
        if distance < best_distance
            best, best_distance = cluster, distance
        end
    end
    return best
end

function learn_codebook(features::Matrix{Float64}; words::Int=16, seed::Int=42, max_iter::Int=30)
    n, d = size(features)
    2 <= words <= n || error("Number of words must be in [2, number of descriptors]")
    max_iter >= 1 || error("max_iter must be >= 1")
    rng = MersenneTwister(seed)
    centers = copy(features[randperm(rng, n)[1:words], :])
    assignments = zeros(Int, n)
    for iteration in 1:max_iter
        changed = false
        counts = zeros(Int, words)
        sums = zeros(Float64, words, d)
        for row in 1:n
            cluster = closest_word(features, row, centers)
            if assignments[row] != cluster
                assignments[row] = cluster
                changed = true
            end
            counts[cluster] += 1
            @inbounds for col in 1:d
                sums[cluster,col] += features[row,col]
            end
        end
        for cluster in 1:words
            if counts[cluster] == 0
                # Seed-fixed deterministic reinitialization for empty clusters.
                centers[cluster,:] = features[rand(rng, 1:n),:]
            else
                @inbounds for col in 1:d
                    centers[cluster,col] = sums[cluster,col] / counts[cluster]
                end
            end
        end
        (!changed && iteration > 1 && all(>(0), counts)) && break
    end
    return centers
end

function visual_transactions(images::Vector{Matrix{Float64}}, codebook::Matrix{Float64})
    size(codebook,2) == 6 || error("Codebook must have 6 feature columns")
    txs = Vector{Vector{Int}}(undef, length(images))
    for (i, img) in enumerate(images)
        desc = dense_descriptors(img)
        txs[i] = sort!(unique([closest_word(desc, row, codebook) for row in 1:size(desc, 1)]))
    end
    return txs
end

function pick_patterns(itemsets::ItemsetSupport; limit::Int=60)
    candidates = [(key, count) for (key, count) in itemsets if length(key) >= 2]
    sort!(candidates; by=x -> (-x[2], length(x[1]), x[1]))
    return [p[1] for p in first(candidates, min(limit, length(candidates)))]
end

function class_pattern_enrichment(txs::Vector{Vector{Int}}, labels::Vector{Int},
                                  itemsets::ItemsetSupport; min_class_count::Int=5)
    n = length(txs)
    n == length(labels) || error("Train data/label count mismatch")
    selected_labels = sort!(unique(labels))
    class_counts = Dict(label => count(==(label), labels) for label in selected_labels)
    txsets = [Set(tx) for tx in txs]
    rows = NamedTuple[]
    for (pattern, support) in itemsets
        length(pattern) < 2 && continue
        p_global = support / n
        class_hits = Dict(label => 0 for label in selected_labels)
        for i in eachindex(txs)
            if all(in(txsets[i]), pattern)
                class_hits[labels[i]] += 1
            end
        end
        for label in selected_labels
            hits = class_hits[label]
            hits < min_class_count && continue
            p_class = hits / class_counts[label]
            push!(rows, (pattern=pattern, digit=label, class_count=hits,
                         global_support=p_global, class_support=p_class,
                         enrichment=p_class/p_global))
        end
    end
    sort!(rows; by=x -> (-x.enrichment, -x.class_count, x.digit, x.pattern))
    return rows
end

function image_features(txs::Vector{Vector{Int}}, words::Int,
                        patterns::AbstractVector{<:Tuple})
    feats = zeros(Float64, length(txs), words+length(patterns))
    for (i, tx) in enumerate(txs)
        for w in tx
            feats[i,w] = 1.0
        end
        current = Set(tx)
        for (j, pattern) in enumerate(patterns)
            feats[i,words+j] = all(in(current), pattern) ? 1.0 : 0.0
        end
    end
    return feats
end

function nearest_centroid_accuracy(train::Matrix{Float64}, ytrain::Vector{Int},
                                   test::Matrix{Float64}, ytest::Vector{Int})
    length(ytrain) == size(train,1) || error("Mismatched training features/labels")
    length(ytest) == size(test,1) || error("Mismatched testing features/labels")
    size(train,2) == size(test,2) || error("Feature dimension mismatch")
    classes = sort!(unique(ytrain))
    centroids = zeros(Float64, length(classes), size(train,2))
    counts = zeros(Int, length(classes))
    for (i, cls) in enumerate(classes)
        indices = findall(==(cls), ytrain)
        counts[i] = length(indices)
        for row in indices, col in 1:size(train,2)
            centroids[i,col] += train[row,col]
        end
        centroids[i,:] ./= counts[i]
    end
    correct = 0
    for row in 1:size(test,1)
        label_idx = closest_word(test, row, centroids)
        correct += (classes[label_idx] == ytest[row])
    end
    return correct / length(ytest)
end

function digits_svg(path::String, images::Vector{Matrix{Float64}}, labels::Vector{Int}; limit::Int=12)
    shown = min(limit, length(images))
    columns = 6
    rows = cld(shown, columns)
    width, height = 6*112+15, rows*130+45
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"$width\" height=\"$height\">")
        println(io, "<rect width=\"100%\" height=\"100%\" fill=\"white\"/>")
        println(io, "<text x=\"10\" y=\"23\" font-family=\"Arial\" font-size=\"18\">UCI Digits: test images</text>")
        for i in 1:shown
            x0 = 10 + ((i-1) % columns)*112
            y0 = 36 + ((i-1) ÷ columns)*130
            for r in 1:8, c in 1:8
                gray = clamp(round(Int, 255*(1-images[i][r,c]/16)), 0, 255)
                println(io, "<rect x=\"$(x0+(c-1)*10)\" y=\"$(y0+(r-1)*10)\" width=\"10\" height=\"10\" fill=\"rgb($gray,$gray,$gray)\"/>")
            end
            println(io, "<text x=\"$x0\" y=\"$(y0+103)\" font-family=\"Arial\" font-size=\"14\">Digit: $(labels[i])</text>")
        end
        println(io, "</svg>")
    end
    return path
end

function run_visual_words(; data_path::String=joinpath(ROOT, "data", "chapter3", "digits8x8.csv"),
                          minsup::Float64=0.12, words::Int=16, seed::Int=42,
                          max_per_class::Int=150, algo::Symbol=:baseline,
                          output_dir::String=joinpath(ROOT, "results", "chapter3", "visual_words"))
    imgs, labels = read_digits(data_path)
    train_imgs, test_imgs, train_y, test_y = split_digits(imgs, labels;
        seed=seed, max_per_class=max_per_class)
    descriptors = collect_descriptors(train_imgs)
    codebook = learn_codebook(descriptors; words=words, seed=seed)
    train_txs = visual_transactions(train_imgs, codebook)
    test_txs = visual_transactions(test_imgs, codebook)
    mkpath(output_dir)
    save_transactions(joinpath(output_dir, "train_transactions.spmf"), train_txs)
    save_transactions(joinpath(output_dir, "test_transactions.spmf"), test_txs)
    write_csv(joinpath(output_dir, "codebook.csv"),
        ["word_id", "mean", "std", "positive_gx", "negative_gx", "positive_gy", "negative_gy"],
        ((i, @sprintf("%.8f", codebook[i,1]), @sprintf("%.8f", codebook[i,2]),
             @sprintf("%.8f", codebook[i,3]), @sprintf("%.8f", codebook[i,4]),
             @sprintf("%.8f", codebook[i,5]), @sprintf("%.8f", codebook[i,6])) for i in 1:words))

    began = time()
    itemsets = mine_itemsets(train_txs, minsup; algo=algo,
                             output=joinpath(output_dir, "train_frequent_itemsets.spmf"))
    elapsed = time() - began
    validate_support(train_txs, itemsets) || error("Support validation failed")
    patterns = pick_patterns(itemsets)
    enrichment = class_pattern_enrichment(train_txs, train_y, itemsets)
    write_csv(joinpath(output_dir, "patterns_by_class.csv"),
        ["visual_words", "digit", "count_in_class", "global_support", "class_support", "enrichment"],
        ((join(("W" * string(i) for i in r.pattern), "+"), r.digit, r.class_count,
          @sprintf("%.8f", r.global_support), @sprintf("%.8f", r.class_support),
          @sprintf("%.8f", r.enrichment)) for r in enrichment))

    # Train the codebook and mine patterns only on train data. Compare a simple
    # nearest-class-centroid classifier using visual words versus words+patterns.
    base_train = image_features(train_txs, words, Tuple{Vararg{Int}}[])
    base_test = image_features(test_txs, words, Tuple{Vararg{Int}}[])
    extra_train = image_features(train_txs, words, patterns)
    extra_test = image_features(test_txs, words, patterns)
    acc_basic = nearest_centroid_accuracy(base_train, train_y, base_test, test_y)
    acc_patterns = nearest_centroid_accuracy(extra_train, train_y, extra_test, test_y)
    write_csv(joinpath(output_dir, "test_accuracy_comparison.csv"),
        ["representation", "n_features", "test_accuracy"],
        [("visual_words", words, @sprintf("%.6f", acc_basic)),
         ("visual_words_plus_patterns", words+length(patterns), @sprintf("%.6f", acc_patterns))])
    write_csv(joinpath(output_dir, "selected_patterns.csv"), ["rank", "visual_words"],
              ((i, join(("W" * string(w) for w in p), "+")) for (i,p) in enumerate(patterns)))
    top = first(enrichment, min(12, length(enrichment)))
    save_horizontal_bars_svg(joinpath(output_dir, "enriched_patterns.svg"),
        ["Digit $(r.digit): " * join(("W" * string(i) for i in r.pattern), "+") for r in top],
        [r.enrichment for r in top], "Enrichment of frequent visual patterns by digit";
        xlabel="P(pattern | class) / P(pattern)")
    digits_svg(joinpath(output_dir, "digits_samples.svg"), test_imgs, test_y)
    open(joinpath(output_dir, "summary.txt"), "w") do io
        println(io, "Dataset: UCI optical recognition digits (8x8 grayscale)")
        println(io, "Train/test images: $(length(train_imgs))/$(length(test_imgs)); seed: $seed")
        println(io, "Descriptors: 9 local gradient patches per image, 6 values per patch; NOT SIFT")
        println(io, "K-means codebook: $words words, trained on train images only")
        println(io, "Algorithm: $algo; minsup: $minsup")
        println(io, "Frequent itemsets: $(length(itemsets)); selected patterns: $(length(patterns))")
        println(io, "Mining elapsed_sec: $(@sprintf("%.4f", elapsed))")
        println(io, "Support cross-check: PASS")
        println(io, "Nearest-centroid accuracy words only: $(@sprintf("%.4f", acc_basic))")
        println(io, "Nearest-centroid accuracy + FIM patterns: $(@sprintf("%.4f", acc_patterns))")
        println(io, "Accuracy improvement is not guaranteed; check actual results.")
    end
    println("VISUAL: $(length(train_imgs)) train + $(length(test_imgs)) test images; " *
            "$(length(itemsets)) itemsets, $(length(patterns)) patterns; support PASS")
    println("Accuracy baseline=$(@sprintf("%.4f", acc_basic)), with patterns=$(@sprintf("%.4f", acc_patterns))")
    println("Output: $output_dir")
    return (; itemsets=length(itemsets), patterns=length(patterns), train=length(train_imgs),
            test=length(test_imgs), base_accuracy=acc_basic,
            pattern_accuracy=acc_patterns, output_dir=output_dir)
end
