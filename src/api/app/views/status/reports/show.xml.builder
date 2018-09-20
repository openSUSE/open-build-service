xml.status_report(uuid: @status_report.uuid) do |xml|
  @checks.each do |check|
    render(partial: 'check', locals: { builder: xml, object: check })
  end

  @missing_checks.each do |name|
    xml.check(name: name, required: true) do |check|
      check.state(:pending)
    end
  end
end
