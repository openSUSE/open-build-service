builder.checks(count: checks.count) do
  checks.each do |check|
    render(partial: 'status/checks/check', locals: { object: check, builder: builder, checkable: check.status_report.try(:checkable) })
  end
end
