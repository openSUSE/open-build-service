xml.status_reports do
  @status_reports.each do |status_report|
    xml.status_report do |xml|
      render(template: 'status/reports/show', locals: { xml: xml, status_report: status_report })
    end
  end
end
