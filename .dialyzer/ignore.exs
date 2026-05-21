[
  # MapSet.difference/2 called with properly constructed MapSets;
  # dialyzer flags the opaque internal representation as a false positive
  {"lib/mix/tasks/compile/telemetria.ex", :call_without_opaque}
]
