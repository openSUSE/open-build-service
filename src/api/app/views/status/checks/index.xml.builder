xml.checks do
  @checks.each do |check|
    render(partial: 'check', locals: { builder: xml, object: check })
  end
  @missing_checks.each do |name|
    xml.check(required: true) do |check|
      check.name(name)
      check.state(:pending)
    end
  end
end
