@testset "Alignment with and without zero-lagged vector matches" begin
    ts = [SingleTimeSeries(rand(10)) for i = 1:3]
    E1 = embed(ts, [1, 2, 3, 3], [1, -1, -1, 0])
    E2 = embed(ts, [1, 2, 3], [1, -1, -1])

    @test all(E1.points[:, 1:3] .== E2.points)
    @test typeof(E1) == GenericEmbedding
    @test typeof(E2) == GenericEmbedding
end


@testset "Embedding dim > 3" begin
    ts2 = [rand(10) for i = 1:3]
    ts3 = [collect(1:10) for i = 1:5]
    # Floats
    E1 = embed(ts2, [1, 2, 3, 3], [1, -1, -1, 0])
    E2 = embed(ts2, [1, 2, 3], [1, -1, -1])

    # Integers
    E3 = embed(ts3, [1, 2, 3, 3, 1], [1, -1, -1, 0, 1])
    E4 = embed(ts3, [1, 2, 3], [1, -1, -1])

    @test all(E1.points[:, 1:3] .== E2.points)
    @test all(E3.points[:, 1:3] .== E4.points)

    @test typeof(E1) == GenericEmbedding
    @test typeof(E2) == GenericEmbedding
    @test typeof(E3) == GenericEmbedding
    @test typeof(E4) == GenericEmbedding
end

@testset "Invariantizing embeddings" begin
    E1 = embed([diff(rand(30)) for i = 1:4], [1, 2, 3, 3], [1, -1, -1, 0])
    inv_E1 =  invariantize(E1)

    @test typeof(inv_E1) == LinearlyInvariantEmbedding
end


@testset "Different dispatch" begin
    u = [randn(10) for i = 1:3]
    v = [collect(1:10) for i = 1:3]
    A = randn(10, 3)
    B = hcat(v...)

    ts_inds = [1, 2, 3]
    embedding_lags = [1, 0, -2]

    # Vector of vectors
    @test typeof(embed(u)) == GenericEmbedding
    @test typeof(embed(v)) == GenericEmbedding
    @test typeof(embed(u, ts_inds, embedding_lags)) == GenericEmbedding
    @test typeof(embed(v, ts_inds, embedding_lags)) == GenericEmbedding

    # Arrays
    @test typeof(embed(A)) == GenericEmbedding
    @test typeof(embed(A, ts_inds, embedding_lags)) == GenericEmbedding

    @test typeof(embed(float.(B))) == GenericEmbedding
    @test typeof(embed(float.(B), ts_inds, embedding_lags)) == GenericEmbedding

end

@testset "Plotting recipes" begin
    emb = embed([diff(rand(30)) for i = 1:3], [1, 2, 3], [1, 0, -1])
    emb_invariant = invariantize(emb)

    # Test plot recipes by calling RecipesBase.apply_recipe with empty dict.
    # It should return a vector of RecipesBase.RecipeData
    d = Dict{Symbol,Any}()

    @test typeof(RecipesBase.apply_recipe(d, emb)) == Array{RecipesBase.RecipeData,1}
    @test typeof(RecipesBase.apply_recipe(d, emb_invariant)) == Array{RecipesBase.RecipeData,1}

end