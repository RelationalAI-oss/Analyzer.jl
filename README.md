# Analyzer

__Possibly useful!__

Statically analyze Julia code for performance problems. 

Usage:

``` julia
Pkg.clone("git@github.com:RelationalAI-oss/Analyzer.jl.git")
using Analyzer
@analyze sum([1,2,3])
```

See `?analyze` for more details.

## TODO

* Point out heap allocations
* Allow asserting type-stable / allocation-free for tests
* Figure out interactive UX rather than just dumping a wall of text
