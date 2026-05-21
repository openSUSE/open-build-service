builder.report(id: report.id, reportable_id: report.reportable_id, reportable_type: report.reportable_type,
               category: report.category,
               created_at: report.created_at, updated_at: report.updated_at) do
  builder.text(report.reason)
end
