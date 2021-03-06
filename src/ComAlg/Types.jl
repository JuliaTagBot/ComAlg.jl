import Base: show

export vector_space, ModFree, ModFreeElem, ModFreeToModFreeMor, free_module

#=
mutable struct MPolyIdlSet{T <: MPolyElem{ <: RingElem}}
  R::MPolyRing{T}
  function MPolyIdlSet{T}(R::MPolyRing{T}) where T
    return new(R)
  end
end

function show(io::IO, I::MPolyIdlSet)
  println(io, "Set of ideals of $(I.R)\n")
end

mutable struct MPolyIdl{T <: MPolyElem{ <:RingElem}}
  gens::Array{T, 1} # initial generators
  parent::MPolyRing{T}
  std::Array{T, 1} # a Groebner basis is known/ computed
  ishomogenous::Bool
  hilbert::Any #PowerSeries

  function MPolyIdl{T}(gens::Array{T, 1}) where T
    r = new()
    r.gens = gens
    return r
  end
end

function show(io::IO, I::MPolyIdl)
  println(io, "ideal in $(I.parent.R), generated by $(I.gens)\n")
end

=#
######################################################################
mutable struct ModFree{T <: Nemo.RingElem}
  ring::Nemo.Ring
  dim::Int
  isfinalized::Bool

  function ModFree{T}(R, n::Int) where T <: Nemo.RingElem
    r = new()
    r.ring = R
    r.dim = n
    r.isfinalized = false
    return r
  end
end


function vector_space(K::Nemo.Field, n::Int)
  return ModFree{elem_type(K)}(K, n)
end

function free_module(R::Nemo.Ring, n::Int)
  return ModFree{elem_type(R)}(R, n)
end

function show(io::IO, M::ModFree)
  print(io, "Free Module of rank $(M.dim) over $(M.ring)\n")
end

function show(io::IO, M::ModFree{<:FieldElem})
  print(io, "Vector Space of dim $(M.dim) over $(M.ring)\n")
end

mutable struct ModFreeElem{T <: Nemo.RingElem}
  coeff::Array{T, 1} # TODO: figure out how to declare a matrix...
  parent::ModFree{T}

  function ModFreeElem{T}(M::ModFree{T}, c::Array{T, 1}) where T <: Nemo.RingElem
    r = new()
    r.parent = M
    r.coeff = c
    return r
  end
end

function (V::ModFree{T})(c::Array{T, 1}) where T <: Nemo.RingElem
  v = ModFreeElem{T}(V, c)
end

function show(io::IO, x::ModFreeElem)
  print(io, "vector: ", x.coeff)
end

mutable struct ModFreeToModFreeMor{T <: Nemo.FieldElem} <: Map{ModFree, ModFree}
  header::Hecke.MapHeader
  map::MatElem{T}

  function ModFreeToModFreeMor{T}(M::ModFree{T}, N::ModFree{T}, map::Nemo.MatElem{T}) where T
    r = new()

    function im(x::ModFreeElem)
      return N(Nemo.matrix(coeff_field(M), 1, dim(M), x.coeff)*map)
    end

    r.header = Hecke.MapHeader(M, N, im)
    r.map = map
    return r
  end
end
(M::ModFreeToModFreeMor{T})(v::ModFreeElem{T}) where T <: RingElem = image(M, v)

function Base.show(io::IO, f::ModFreeToModFreeMor)
  println(io, "Map with following data")
  print(io, "Domain:\n$(domain(f))")
  print(io, "Codomain:\n$(codomain(f))")
  print(io, "Map:\n$(f.map)")
end

#############################################################
# same again for ModDed
# and
# Subquo....
mutable struct ModSub{T <: RingElem}
  gen::MatElem{T} # meant to be in R^n as the module generated by the rows of gen
  isGB::Bool
  gen_gb::MatElem{T}
  isfinalized::Bool

#  gen_gb_sing :: smodule

  function ModSub{T}(m::MatElem{T}) where T
    r = new()
    r.gen = m
    r.isfinalized = false
    return r
  end
end


function Base.show(io::IO, S::ModSub)
  println(io, "sub-module, generated by")
  for i=1:rows(S.gen)
    println(io, "  g[$i] = ", sub(S.gen, i:i, 1:cols(S.gen)))
  end
end

mutable struct ModSubLazy{T <: RingElem}
  #the intersection of A and B, but not (yet) computed.
  A::ModSub{T}
  B::ModSub{T}
end

function Base.show(io::IO, S::ModSubLazy)
  println(io, "intersection of")
  println(io, A)
  println(io, "and")
  println(io, B)
end

mutable struct ModSubQuo{T <: RingElem} # any ring where we can do "std": Euc, MPoly
  num::ModSub{T}
  den::Union{ModSub{T}, ModSubLazy{T}}
  isfinalized::Bool

  function ModSubQuo{T}( ; ignore::Type = T) where T <: RingElem
    r = new()
    r.isfinalized = false
    return r
  end
end

function Base.show(io::IO, M::ModSubQuo)
  print(io, "general sub-quotient with $(rows(M.num.gen)) generators")
  if isdefined(M, :den)
    print(io, " and some known relations\n")
  else
    print(io, "\n")
  end
end

mutable struct ModSubQuoElem{T <: RingElem}
  coeff::Array{T, 1} # TODO: figure out how to declare a matrix...
  parent::ModSubQuo{T}

  function ModSubQuoElem{T}(M::ModSubQuo{T}, c::Array{T, 1}) where T <: RingElem
    @assert length(c) == ngens(M)
    r = new()
    r.parent = M
    r.coeff = c
    return r
  end
end

function (V::ModSubQuo{T})(c::Array{T, 1}) where T <: Nemo.RingElem
  v = ModSubQuoElem{T}(V, c)
end

function Base.show(io::IO, x::ModSubQuoElem)
  print(io, "SubQuoElem: ", x.coeff)
end

mutable struct ModSubQuoToFreeMor{T <: Nemo.RingElem} <: Map{ModSubQuo{T}, ModFree{T}}
  header::Hecke.MapHeader
  map::MatElem{T}

  function ModSubQuoToFreeMor{T}(M::ModSubQuo{T}, N::ModFree{T}, map::MatElem{T}) where T
    r = new()
    function im(x::ModSubQuoElem)
      return N(Nemo.matrix(coeff_ring(M), 1, ngens(M), x.coeff)*map)
    end
    r.header = Hecke.MapHeader(M, N, im)
    r.map = map
    return r
  end
end

(M::ModSubQuoToFreeMor{T})(v::ModSubQuoElem{T}) where T <: RingElem = image(M, v)

function Base.show(io::IO, f::ModSubQuoToFreeMor)
  println(io, "Map with following data")
  print(io, "Domain:\n$(domain(f))")
  print(io, "Codomain:\n$(codomain(f))")
  print(io, "Map:\n$(f.map)")
end


