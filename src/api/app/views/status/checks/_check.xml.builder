required = checkable.nil? ? false : checkable.required_checks.include?(object.name)
builder.check(name: object.name, required: required) do |check|
  check.state object.state
  check.short_description object.short_description
  check.url object.url
end
