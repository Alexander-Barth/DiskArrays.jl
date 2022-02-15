
macro implement_array_methods(t)
    quote
        Base.Array(a::$t) = DiskArrays._Array(a)
        Base.copyto!(dest::$t, source::AbstractArray) = DiskArrays._copyto!(dest, source)
        Base.copyto!(dest::AbstractArray, source::$t) = DiskArrays._copyto!(dest, source)
        Base.copyto!(dest::$t, source::$t) = DiskArrays._copyto!(dest, source)
        function Base.copyto!(dest::$t, Rdest::CartesianIndices, src::AbstractArray, Rsrc::CartesianIndices)
            DiskArrays._copyto!(dest, Rdest, src, Rsrc)
        end
        function Base.copyto!(dest::AbstractArray, Rdest::CartesianIndices, src::$t, Rsrc::CartesianIndices)
            DiskArrays._copyto!(dest, Rdest, src, Rsrc)
        end
        function Base.copyto!(dest::$t, Rdest::CartesianIndices, src::$t, Rsrc::CartesianIndices)
            DiskArrays._copyto!(dest, Rdest, src, Rsrc)
        end
        Base.reverse(a::$t, dims=:) = DiskArrays._reverse(a, dims)
        # Here we extend the unexported `_replace` method, but we replicate 
        # much less Base functionality by extending it rather than `replace`.
        function Base._replace!(new::Base.Callable, res::AbstractArray, A::$t, count::Int)
            DiskArrays._replace!(new, res, A, count)
        end
        function Base._replace!(new::Base.Callable, res::$t, A::AbstractArray, count::Int)
            DiskArrays._replace!(new, res, A, count)
        end
        function Base._replace!(new::Base.Callable, res::$t, A::$t, count::Int)
            DiskArrays._replace!(new, res, A, count)
        end
    end
end

# Use broadcast to copy to a new Array
function _Array(a::AbstractArray{T,N}) where {T,N}
    dest = Array{T,N}(undef, size(a))
    dest .= a
    return dest
end

# Use broadcast to copy
_copyto!(dest::AbstractArray{<:Any,N}, source::AbstractArray{<:Any,N}) where N = dest .= source
function _copyto!(dest::AbstractArray, source::AbstractArray)
    # TODO make this more specific so we are reshaping the Non-DiskArray more often.
    reshape(dest, size(source)) .= source
    return dest
end
_copyto!(dest, Rdest, src, Rsrc) = view(dest, Rdest) .= view(src, Rsrc)

# Use a view for lazy reverse
_reverse(a, dims::Colon) = _reverse(a, ntuple(identity, ndims(a)))
_reverse(a, dims::Int) = _reverse(a, (dims,))
function _reverse(A, dims::Tuple)
    rev_axes = map(ntuple(identity, ndims(A)), axes(A)) do d, a
        ax = StepRange(a)
        d in dims ? reverse(ax) : ax
    end
    return view(A, rev_axes...)
end

# Use broadcast instead of a loop. 
# The `count` argument is disallowed as broadcast is not sequential.
function _replace!(new, res::AbstractArray, A::AbstractArray, count::Int)
    count < length(res) && throw(ArgumentError("`replace` on DiskArrays objects cannot use a count value"))
    broadcast!(new, res, A)
end