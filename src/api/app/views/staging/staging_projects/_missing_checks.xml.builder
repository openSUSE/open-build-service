builder.missing_checks(count: missing_checks.count) do
  missing_checks.each do |name|
    builder.missing_check(name: name, state: :pending, required: true)
  end
end
