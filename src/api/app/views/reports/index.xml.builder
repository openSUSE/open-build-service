xml.reports do
  render(partial: 'reports/report', collection: @reports, locals: { builder: xml })
end
