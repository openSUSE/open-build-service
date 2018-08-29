builder.check(id: object.id, required: object.required?) do |check|
  check.name object.name
  check.state object.state
  check.short_description object.short_description
  check.url object.url
end
