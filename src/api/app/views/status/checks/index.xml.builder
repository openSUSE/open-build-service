xml.checks do
  @checks.each do |check|
    render(partial: 'check', locals: { builder: xml, object: check })
  end
end
