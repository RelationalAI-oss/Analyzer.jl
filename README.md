# Analyzer

__Possibly useful!__

Statically analyze Julia code for performance problems. 

Usage:

``` julia
Pkg.clone("git@github.com:RelationalAI-oss/Analyzer.jl.git")
using Analyzer
julia> @analyze sum(Any[1,2,3])

sum(::Array{Any,1}) in Base at reduce.jl:359
  Calls: _mapreduce(::Base.#identity, ::Base.#+, ::IndexLinear, ::Array{Any,1}) in Base at reduce.jl:262
  NotConcretelyTyped: $(Expr(:invoke, MethodInstance for _mapreduce(::Base.#identity, ::Base.#+, ::IndexLinear, ::Array{Any,1}), :(Base._mapreduce), :(Base.identity), :(Base.+), :($(QuoteNode(IndexLinear()))), :(a)))

_mapreduce(::Base.#identity, ::Base.#+, ::IndexLinear, ::Array{Any,1}) in Base at reduce.jl:262
  Called from: sum(::Array{Any,1}) in Base at reduce.jl:359
  Calls: mapreduce_impl(::Base.#identity, ::Base.#+, ::Array{Any,1}, ::Int64, ::Int64, ::Int64) in Base at reduce.jl:178
  NotConcretelyTyped: (Base.r_promote)(op::Base.#+, (Base.zero)($(Expr(:static_parameter, 1)))::Any)::Any
  DynamicCall: (Base.r_promote)(op::Base.#+, (Base.zero)($(Expr(:static_parameter, 1)))::Any)::Any
  NotConcretelyTyped: (Base.zero)($(Expr(:static_parameter, 1)))::Any
  DynamicCall: (Base.zero)($(Expr(:static_parameter, 1)))::Any
  NotConcretelyTyped: (Base.arrayref)(A::Array{Any,1}, 1)::Any
  NotConcretelyTyped: (Base.r_promote)(op::Base.#+, a1::Any)::Any
  DynamicCall: (Base.r_promote)(op::Base.#+, a1::Any)::Any
  NotConcretelyTyped: (Base.arrayref)(A::Array{Any,1}, i::Int64)::Any
  NotConcretelyTyped: (Base.arrayref)(A::Array{Any,1}, SSAValue(1))::Any
  NotConcretelyTyped: (op::Base.#+)((Base.r_promote)(op::Base.#+, a1::Any)::Any, (Base.r_promote)(op::Base.#+, a2::Any)::Any)::Any
  DynamicCall: (op::Base.#+)((Base.r_promote)(op::Base.#+, a1::Any)::Any, (Base.r_promote)(op::Base.#+, a2::Any)::Any)::Any
  NotConcretelyTyped: (Base.r_promote)(op::Base.#+, a1::Any)::Any
  DynamicCall: (Base.r_promote)(op::Base.#+, a1::Any)::Any
  NotConcretelyTyped: (Base.r_promote)(op::Base.#+, a2::Any)::Any
  DynamicCall: (Base.r_promote)(op::Base.#+, a2::Any)::Any
  NotConcretelyTyped: (Base.arrayref)(A::Array{Any,1}, SSAValue(3))::Any
  NotConcretelyTyped: (op::Base.#+)(s::Any, Ai::Any)::Any
  DynamicCall: (op::Base.#+)(s::Any, Ai::Any)::Any
  NotConcretelyTyped: $(Expr(:invoke, MethodInstance for mapreduce_impl(::Base.#identity, ::Base.#+, ::Array{Any,1}, ::Int64, ::Int64, ::Int64), :(Base.mapreduce_impl), :(f), :(op), :(A), 1, :((Core.getfield)(inds, :stop)::Int64), 1024))

mapreduce_impl(::Base.#identity, ::Base.#+, ::Array{Any,1}, ::Int64, ::Int64, ::Int64) in Base at reduce.jl:178
  Called from: _mapreduce(::Base.#identity, ::Base.#+, ::IndexLinear, ::Array{Any,1}) in Base at reduce.jl:262
  Called from: mapreduce_impl(::Base.#identity, ::Base.#+, ::Array{Any,1}, ::Int64, ::Int64, ::Int64) in Base at reduce.jl:178
  Calls: mapreduce_impl(::Base.#identity, ::Base.#+, ::Array{Any,1}, ::Int64, ::Int64, ::Int64) in Base at reduce.jl:178
  NotConcretelyTyped: (Base.arrayref)(A::Array{Any,1}, ifirst::Int64)::Any
  NotConcretelyTyped: (Base.r_promote)(op::Base.#+, a1::Any)::Any
  DynamicCall: (Base.r_promote)(op::Base.#+, a1::Any)::Any
  NotConcretelyTyped: (Base.arrayref)(A::Array{Any,1}, ifirst::Int64)::Any
  NotConcretelyTyped: (Base.arrayref)(A::Array{Any,1}, (Base.add_int)(ifirst::Int64, 1)::Int64)::Any
  NotConcretelyTyped: (op::Base.#+)((Base.r_promote)(op::Base.#+, a1::Any)::Any, (Base.r_promote)(op::Base.#+, a2::Any)::Any)::Any
  DynamicCall: (op::Base.#+)((Base.r_promote)(op::Base.#+, a1::Any)::Any, (Base.r_promote)(op::Base.#+, a2::Any)::Any)::Any
  NotConcretelyTyped: (Base.r_promote)(op::Base.#+, a1::Any)::Any
  DynamicCall: (Base.r_promote)(op::Base.#+, a1::Any)::Any
  NotConcretelyTyped: (Base.r_promote)(op::Base.#+, a2::Any)::Any
  DynamicCall: (Base.r_promote)(op::Base.#+, a2::Any)::Any
  NotConcretelyTyped: (Base.arrayref)(A::Array{Any,1}, ret@_29::Int64)::Any
  NotConcretelyTyped: (op::Base.#+)(v::Any, ai::Any)::Any
  DynamicCall: (op::Base.#+)(v::Any, ai::Any)::Any
  NotConcretelyTyped: $(Expr(:invoke, MethodInstance for mapreduce_impl(::Base.#identity, ::Base.#+, ::Array{Any,1}, ::Int64, ::Int64, ::Int64), :(Base.mapreduce_impl), :(f), :(op), :(A), :(ifirst), :(imid), :(blksize)))
  NotConcretelyTyped: $(Expr(:invoke, MethodInstance for mapreduce_impl(::Base.#identity, ::Base.#+, ::Array{Any,1}, ::Int64, ::Int64, ::Int64), :(Base.mapreduce_impl), :(f), :(op), :(A), :((Base.add_int)(imid, 1)::Int64), :(ilast), :(blksize)))
  NotConcretelyTyped: (op::Base.#+)(v1::Any, v2::Any)::Any
  DynamicCall: (op::Base.#+)(v1::Any, v2::Any)::Any
```

See `?analyze` for more details.

## TODO

* Point out heap allocations
* Allow asserting type-stable / allocation-free for tests
* Figure out interactive UX rather than just dumping a wall of text
