builder.checks(count: checks.count) do
  checks.each do |check|
    render(partial: 'status/checks/check', locals: { object: check, builder: builder })
  end
end
