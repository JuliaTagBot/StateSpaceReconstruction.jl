@reexport module Embeddings

using RecipesBase
using Parameters

using Simplices: Delaunay.delaunayn
using SimplexSplitting: centroids_radii2, heaviside0
using ..TimeSeries: SingleTimeSeries


""" Abstract Embedding type. """
abstract type AbstractEmbedding end


dimension(E::AbstractEmbedding) = size(e.points, 2)
npoints(E::AbstractEmbedding) = size(e.points, 1)
points(E::AbstractEmbedding) = e.points
ntimeseries(E::AbstractEmbedding) = length(e.which_ts)
timeseries(E::AbstractEmbedding) = e.which_ts
which_ts(E::AbstractEmbedding) = e.which_ts
in_which_pos(E::AbstractEmbedding) = e.in_which_pos
at_what_lags(E::AbstractEmbedding) = e.at_what_lags

function Base.summary(E::T) where T<:AbstractEmbedding
    npts = size(E.points, 1)
    D = size(E.points, 2)
    binningtype = typeof(E)
    return "$npts-point $D-dimensional $(binningtype)."
end

function matstring(E::T) where T<:AbstractEmbedding
    fields = fieldnames(E)
    fields_str = String.(fields)
    maxlength = maximum([length(str) for str in fields_str]) + 2
    fields_str = [fields_str[i] *
                repeat(" ", maxlength - length(fields_str[i])) for i = 1:length(fields_str)]

    summaries = [join(":"*String(fields_str[i])*summary(getfield(E, fields[i]))*"\n") for i = 1:length(fields_str)] |> join
    infoline = "The following fields are available:\n"

    return summary(E)#*"\n\n"*infoline*summaries
end

Base.show(io::IO, E::T) where {T<:AbstractEmbedding} = println(io, matstring(E))

"""
An embedding of a set of points. Has the fields
1. `points::Array{Float64, 2}`. The points furnishing the embedding
2. `ts::Vector{Vector{Float64}}`. The time series used to construct the embedding. One for
        each column of `embedding`.
3. `in_which_pos::Vector{Int}`. Which time series are in which column of `embedding`?
4. `at_what_lags::Vector{Int}`. Embedding lag for each column of `embedding`
5. `dim::Int`. The dimension of the embedding
"""
struct Embedding <: AbstractEmbedding
    points::Array{Float64, 2}
    which_ts::Vector{SingleTimeSeries{Float64}}
    in_which_pos::Vector{Int}
    at_what_lags::Vector{Int}
    dim::Int
end

"""
An embedding in which the last point is guaranteed to lie within the convex
hull of the preceding points.
"""
struct LinearlyInvariantEmbedding <: AbstractEmbedding
    points::Array{Float64, 2}
    ts::Vector{SingleTimeSeries{Float64}}
    in_which_pos::Vector{Int}
    at_what_lags::Vector{Int}
    dim::Int
end

function Base.summary(E::LinearlyInvariantEmbedding)
    npts = size(E.points, 1)
    dim = E.dim
    binningtype = typeof(E)
    return """$npts-point $dim-dimensional $(binningtype).

    This embedding is *linearly invariant*  under the action of the forward linear map
    of the embeddings' state vectors one step ahead in time. This mean that the last
    point of the embedding is contained within the convex hull of the previous points."""
end

""" An embedding holding only its points and no information about the embedding itself."""
struct SimpleEmbedding <: AbstractEmbedding
    points::Array{Float64, 2}
end

function embed(ts::Vector{SingleTimeSeries{Float64}},
               in_which_pos::Vector{Int},
               at_what_lags::Vector{Int})
    dim = length(in_which_pos)
    minlag, maxlag = minimum(at_what_lags), maximum(at_what_lags)
    npts = length(ts[1].ts) - (maxlag + abs(minlag))
    E = zeros(Float64, npts, dim)

    for i in 1:length(in_which_pos)
        ts_ind = in_which_pos[i]
        TS = ts[ts_ind].ts
        lag = at_what_lags[i]

        if lag > 0
            E[:, i] = TS[((1 + abs(minlag)) + lag):(end - maxlag) + lag]
        elseif lag < 0
            E[:, i] = TS[((1 + abs(minlag)) - abs(lag)):(end - maxlag - abs(lag))]
        elseif lag == 0
            E[:, i] = TS[(1 + abs(minlag)):(end - maxlag)]
        end
    end

    Embedding(E, ts, in_which_pos, at_what_lags, dim)
end

embed(ts::Vector{Vector{T}} where T<:Number) = embed(
    	[SingleTimeSeries(float.(ts[i])) for i = 1:length(ts)],
    	[i for i in 1:length(ts)],
    	[0 for i in 1:length(ts)]
)

"""
	embed(ts::Vector{SingleTimeSeries{Float64}},
			in_which_pos::Vector{Int},
			at_what_lags::Vector{Int})

Embed a set of vectors.

## Arguments
1. `which_ts::Vector{Vector{Float64}}`. This is a vector containing the time series to embed.
    - Example: which_ts = [ts1, ts2].
2. `in_which_pos::Vector{Int}``. The length of in_which_pos gives the dimension of the
    embedding. The value of the ith element of in_which_pos indicates which time series in
    the ith column of the embedding.
    - **Example 1**: if `which_ts = [ts1, ts2]`, then we index ts1 as 1 and ts2 as 2.
        Setting `in_which_pos = [2, 2, 1]` will result in a 3-dimensional embedding where
        `ts2` will appear in columns 1 and 2, while `ts1` will appear in column 3.
    - **Example 2**: If `which_ts = [ts1, ts2, ts3]`, then `in_which_pos = [2,1,2,3,3]`
        results in a 5-dimensional embedding where `ts1`appears in column 2, `ts2` appears
        in columns 1 and 3, while `ts3`appears in columns 4 and 5.
3. `at_what_lags::Vector{Int}` sets the lag in each column. Must be the same length as
    `which_ts`.
    - **Example**: if `in_which_pos = [2, 2, 1]`, then  `at_what_lags = [1, 0, -1]` means
        that the lag in column 1 is 1, the lag in the second column is 0 and the lag in
        the third column is -1.

"""
embed(ts::Vector{Vector{T}} where T<:Number, in_which_pos::Vector{Int}, at_what_lags::Vector{Int} where T<:Real) =
    embed([SingleTimeSeries(float.(ts[i])) for i = 1:length(ts)], in_which_pos, at_what_lags)

"""
Default embedding of a `npts`-by-`dim` array of points.
"""
embed(A::AbstractArray{Float64, 2}) = embed(
    	[A[:, i] for i = 1:size(A, 2)],
    	[i for i in 1:size(A, 2)],
    	[0 for i in 1:size(A, 2)])

embed(A::AbstractArray{Int, 2}) = embed(float.(A))

embed(A::AbstractArray{Float64, 2}, in_which_pos::Vector{Int}, at_what_lags::Vector{Int}) =
    embed([A[:, i] for i = 1:size(A, 2)], in_which_pos, at_what_lags)

embed(A::AbstractArray{Int, 2}, in_which_pos::Vector{Int}, at_what_lags::Vector{Int}) =
        embed([float.(A[:, i]) for i = 1:size(A, 2)], in_which_pos, at_what_lags)

include("embedding/invariantize.jl")



@recipe function f(E::AbstractEmbedding)
    if E.dim > 3
        warn("Embedding dim > 3, plotting three first axes")
        pts = E.points[:, 1:3]
    end
    pts = E.points
    X = pts[:, 1]
    Y = pts[:, 2]
    Z = pts[:, 3]
    X, Y, Z
end


export
AbstractEmbedding,
Embedding,
SimpleEmbedding,
LinearlyInvariantEmbedding,
embed,
npoints,
dimension,
which_ts,
in_which_pos,
at_what_lags,
points,
ntimeseries,
timeseries,
invariantize,
invariant_under_forwardlinearmap

end #module end
