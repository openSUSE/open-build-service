xml.reports(params.slice(*%i[offset limit]).permit!.to_h.compact_blank) do
  render(partial: 'reports/report', collection: @reports, locals: { builder: xml })
end
