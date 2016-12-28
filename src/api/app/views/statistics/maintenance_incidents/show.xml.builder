xml.maintenanceincident(project: @project.name) do
  @maintenance_statistics.each do |maintenance_statistic|
    render( partial: "statistics/maintenance_incidents/#{maintenance_statistic.type}", locals: { builder: xml, maintenance_statistic: maintenance_statistic })
  end
end
