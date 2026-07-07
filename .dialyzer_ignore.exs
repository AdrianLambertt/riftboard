[
  # Known Dialyzer/Ecto.Multi opaque-type false positive on unmodified
  # mix phx.gen.auth boilerplate (Ecto.Multi.new() |> Ecto.Multi.update(...)
  # in a pipe trips opaqueness checking for the struct literal).
  {"lib/riftboard/accounts.ex", :call_without_opaque}
]
