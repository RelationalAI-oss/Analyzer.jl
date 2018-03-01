module Analyzer

function get_method_instance(f, typs) ::Core.MethodInstance
  world = ccall(:jl_get_world_counter, UInt, ())
  tt = typs isa Type ? Tuple{typeof(f), typs.parameters...} : Tuple{typeof(f), typs...}
  results = Base._methods_by_ftype(tt, -1, world)
  @assert length(results) == 1 "get_method_instance should return one method, instead returned $(length(results)) methods: $results"
  (_, _, meth) = results[1]
  # TODO not totally sure what jl_match_method is needed for - I think it's just extracting type parameters like `where {T}`
  (ti, env) = ccall(:jl_match_method, Any, (Any, Any), tt, meth.sig)::SimpleVector
  meth = Base.func_for_method_checked(meth, tt)
  linfo = ccall(:jl_specializations_get_linfo, Ref{Core.MethodInstance}, (Any, Any, Any, UInt), meth, tt, env, world)
end

function get_code_info(method_instance::Core.MethodInstance) ::Tuple{CodeInfo, Type}
  world = ccall(:jl_get_world_counter, UInt, ())
  # TODO inlining=false would make analysis easier to follow, but it seems to break specialization on function types
  params = Core.Inference.InferenceParams(world)
  optimize = true 
  cache = false # not sure if cached copies use the same params
  (_, code_info, return_typ) = Core.Inference.typeinf_code(method_instance, optimize, cache, params)
  (code_info, return_typ)
end

"Does this expression never have a real type?"
function is_untypeable(expr::Expr)
  expr.head in [:(=), :line, :boundscheck, :gotoifnot, :return, :meta, :inbounds, :throw, :simdloop] || (expr.head == :call && expr.args[1] == :throw)
end

is_untypeable(other) = true

"Does this look like error reporting code ie not worth looking inside?"
function is_error_path(expr)
  expr == :throw ||
  expr == :throw_boundserror || 
  expr == :error ||
  expr == :assert || 
  (expr isa QuoteNode && is_error_path(expr.value)) || 
  (expr isa Expr && expr.head == :(.) && is_error_path(expr.args[2])) ||
  (expr isa GlobalRef && is_error_path(expr.name)) ||
  (expr isa Core.MethodInstance && is_error_path(expr.def.name))
end

"Is it pointless to look inside this expression?"
function should_ignore(expr::Expr)
  is_error_path(expr.head) || 
  (expr.head == :call && is_error_path(expr.args[1])) ||
  (expr.head == :invoke && is_error_path(expr.args[1]))
end

function is_builtin_or_intrinsic(expr::GlobalRef)
  fun = getfield(expr.mod, expr.name) 
  fun isa Core.Builtin || fun isa Core.IntrinsicFunction
end

is_builtin_or_intrinsic(other) = false

function is_dynamic_call(expr::Expr)
  expr.head == :call && !is_builtin_or_intrinsic(expr.args[1])
end

@enum WarningKind NotConcretelyTyped Boxed DynamicCall

"Used to refer to the result type of a method, instead of printing out the entire method body"
struct MethodResult 
  typ::Type
end

"A location at which a warning can occur"
const Location = Union{Expr, TypedSlot, MethodResult}

struct Warning
  kind::WarningKind
  location::Location
end

struct Warnings
  code_info::CodeInfo # needed for nice printing of Slot
  warnings::Vector{Warning}
end

function warn_type!(location::Location, typ::Type, warnings::Vector{Warning})
  if !isleaftype(typ) && !is_untypeable(location)
    push!(warnings, Warning(NotConcretelyTyped, location))
  end
  
  if typ == Core.Box
    push!(warnings, Warning(Boxed, location))
  end
end

function warn!(result::MethodResult, warnings::Vector{Warning})
  warn_type!(result, result.typ, warnings)
end

function warn!(expr::Expr, warnings::Vector{Warning})
  # many Exprs always have type Any
  if !(expr.head in [:(=), :line, :boundscheck, :gotoifnot, :return, :meta, :inbounds]) && !(expr.head == :call && expr.args[1] == :throw) 
    warn_type!(expr, expr.typ, warnings)
    if is_dynamic_call(expr)
      push!(warnings, Warning(DynamicCall, expr))
    end
  end
end

function warn!(slot::TypedSlot, warnings::Vector{Warning})
  warn_type!(slot, slot.typ, warnings)
end

function get_warnings(method_instance::Core.MethodInstance)
  code_info, return_typ = get_code_info(method_instance)
  warnings = Warning[]
  
  warn!(MethodResult(return_typ), warnings)
  
  slot_is_used = [false for _ in code_info.slotnames]
  function walk_expr(expr)
      if isa(expr, Slot)
        slot_is_used[expr.id] = true
      elseif isa(expr, Expr)
        if !should_ignore(expr)
          warn!(expr, warnings)
          foreach(walk_expr, expr.args)
        end
      end
  end
  foreach(walk_expr, code_info.code)
  
  for (slot, is_used) in enumerate(slot_is_used)
    if is_used
      typ = code_info.slottypes[slot]
      warn!(TypedSlot(slot, typ), warnings)
    end
  end
  
  Warnings(code_info, warnings)
end

"Return all function calls in the method whose argument types can be determined statically"
function get_child_calls(method_instance::Core.MethodInstance)
  code_info, return_typ = get_code_info(method_instance)
  calls = Set{Core.MethodInstance}()
  
  function walk_expr(expr)
      if isa(expr, Core.MethodInstance)
        push!(calls, expr)
      elseif isa(expr, Expr)
        if !should_ignore(expr)
          foreach(walk_expr, expr.args)
        end
      end
  end
  foreach(walk_expr, code_info.code)
  
  calls
end

"A node in the call graph"
struct CallNode
  call::Core.MethodInstance
  parent_calls::Set{Core.MethodInstance}
  child_calls::Set{Core.MethodInstance}
end

"Return as much of the call graph of `method_instance` as can be determined statically"
function get_call_graph(method_instance::Core.MethodInstance, max_calls=1000::Int64) ::Vector{CallNode}
  all = Dict{Core.MethodInstance, CallNode}()
  ordered = Vector{Core.MethodInstance}()
  unexplored = Set{Tuple{Union{Void, Core.MethodInstance}, Core.MethodInstance}}(((nothing, method_instance),))
  for _ in 1:max_calls
    if isempty(unexplored)
      return [all[call] for call in ordered]
    end
    (parent, call) = pop!(unexplored)
    child_calls= get_child_calls(call)
    parent_calls = parent == nothing ? Set() : Set((parent,))
    all[call] = CallNode(call, parent_calls, child_calls)
    push!(ordered, call)
    for child_call in child_calls
      if !haskey(all, child_call)
        push!(unexplored, (call, child_call))
      else
        push!(all[child_call].parent_calls, call)
      end
    end
  end
  error("get_call_graph reached $max_calls calls and gave up")
end

function pretty(method_instance::Core.MethodInstance)
  original = string(method_instance)
  shortened = replace(original, "MethodInstance for ", "")
  method = method_instance.def
  "$shortened in $(method.module) at $(method.file):$(method.line)"
end

function pretty(code_info::CodeInfo, warning::Warning)
  slotnames = Base.sourceinfo_slotnames(code_info)
  buffer = IOBuffer()
  io = IOContext(buffer, :TYPEEMPHASIZE => true, :SOURCEINFO => code_info, :SOURCE_SLOTNAMES => slotnames)
  Base.emphasize(io, string(warning.kind)); print(io, ": "); Base.show_unquoted(io, warning.location)
  String(buffer)
end

function pretty(code_info::CodeInfo, return_typ::Type)
  slotnames = Base.sourceinfo_slotnames(code_info)
  buffer = IOBuffer()
  io = IOContext(buffer, :TYPEEMPHASIZE => true, :SOURCEINFO => code_info, :SOURCE_SLOTNAMES => slotnames)
  body = Expr(:body)
  body.args = code_info.code
  body.typ = return_typ
  Base.show_unquoted(io, body)
  String(buffer)
end

doc"""
    analyze(filter::Function, f::Function, typs::NTuple{N, Type}) where {N}

Analyzes `f(typs...)` for potential performance problems:
  * computes as much of the call graph as can be statically determined, starting at `f(typs...)`
  * checks for non-concrete inferred types in each node of the call graph
  * for each node where `filter(method_instance::Core.MethodInstance) == true`, prints out the node and any non-concrete inferred types that were detected
  
    analyze(f::Function, typs::NTuple{N, Type}) where {N}

Equivalent to `analyze((_) -> true, f, typs)` ie it prints out the entire call graph.

# Examples

``` jldoctest
julia> y = 1
1

julia> foo(x) = x + y
foo (generic function with 1 method)

julia> bar(x) = foo(x) + foo(x)
bar (generic function with 1 method)

julia> analyze(bar, (Int64,))

bar(::Int64) in Main at none:1
  Calls: foo(::Int64) in Main at none:1
  NotConcretelyTyped: Analyzer.MethodResult(Any)
  NotConcretelyTyped: ($(Expr(:invoke, MethodInstance for foo(::Int64), :(Main.foo), :(x))) + $(Expr(:invoke, MethodInstance for foo(::Int64), :(Main.foo), :(x))))::Any
  NotConcretelyTyped: $(Expr(:invoke, MethodInstance for foo(::Int64), :(Main.foo), :(x)))
  NotConcretelyTyped: $(Expr(:invoke, MethodInstance for foo(::Int64), :(Main.foo), :(x)))
begin
    return ($(Expr(:invoke, MethodInstance for foo(::Int64), :(Main.foo), :(x))) + $(Expr(:invoke, MethodInstance for foo(::Int64), :(Main.foo), :(x))))::Any
end::Any

foo(::Int64) in Main at none:1
  Called from: bar(::Int64) in Main at none:1
  NotConcretelyTyped: Analyzer.MethodResult(Any)
  NotConcretelyTyped: (x::Int64 + Main.y)::Any
begin
    return (x::Int64 + Main.y)::Any
end::Any
```
"""
function analyze end

function analyze(filter::Function, f::Function, typs::NTuple{N, Type}) where {N}
  for call_node in get_call_graph(get_method_instance(f, typs))
    if filter(call_node.call)
      println();
      print(pretty(call_node.call)); println();
      for parent_call in call_node.parent_calls
        print("  Called from: "); print(pretty(parent_call)); println();
      end
      for child_call in call_node.child_calls
        print("  Calls: "); print(pretty(child_call)); println();
      end
      warnings = get_warnings(call_node.call)
      for warning in warnings.warnings
        print("  "); print(pretty(warnings.code_info, warning)); println();
      end
      if !isempty(warnings.warnings)
        code_info, return_typ = get_code_info(call_node.call)
        println(pretty(code_info, return_typ))
      end
    end
  end
end

analyze(f::Function, typs::NTuple{N, Type}) where {N} = analyze((_)->true, f, typs)

"""
    @analyze f(x,y)
   
Equivalent to `analyze(f, (typeof(x), typeof(y)))`


    @analyze(my_filter, f(x,y))
   
    @analyze(f(x,y)) do method_instance
      my_filter(method_instance)
    end
    
Equivalent to `analyze(my_filter, f, (typeof(x), typeof(y)))`
"""
:(@analyze)

_analyze(filter::Function, f::Function, typs::Type) = analyze(filter, f, tuple(typs.parameters...))
_analyze(f::Function, typs::Type) = analyze(f, tuple(typs.parameters...))

@eval begin
  macro analyze(ex0)
     Base.gen_call_with_extracted_types($(Expr(:quote, :_analyze)), ex0)
  end
  
  macro analyze(filter, ex0)
    expr = Base.gen_call_with_extracted_types($(Expr(:quote, :_analyze)), ex0)
    insert!(expr.args, 2, esc(filter))
    expr
  end
end

export analyze, @analyze

end 
