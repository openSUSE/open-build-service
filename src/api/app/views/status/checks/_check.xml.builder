builder.check(name: object.name, required: object.required?) do |check|
  check.state object.state
  check.short_description object.short_description
  check.url object.url
end
