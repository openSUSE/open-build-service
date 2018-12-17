builder.check(name: object.name, required: checkable.required_checks.include?(object.name)) do |check|
  check.state object.state
  check.short_description object.short_description
  check.url object.url
end
