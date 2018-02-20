# Analyzer

__Not yet working enough to be useful!__

Statically analyze Julia code for performance problems. 

Usage:

``` julia
Pkg.clone("git@github.com:RelationalAI/Analyzer.jl.git")
using Analyzer
@analyze sum([1,2,3])
```

See `?analyze` for more details.

## TODO

* doesn't warn on dynamic calls
* unsure whether foo(Type{T} where T) is dynamic or underspecialized 
* relatedly, doesn't seem to handle specialization on functions - eg sum([1,2,3])
* doesn't show calls to builtins
* distinguish better between static and dynamic calls
* invoke with non-leaf types may be dynamic?
* call with leaf types may be static? 
