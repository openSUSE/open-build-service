builder.check(id: object.id) do |check|
  check.url object.url
  check.state object.state
  check.short_description object.short_description
  check.name object.name
end
