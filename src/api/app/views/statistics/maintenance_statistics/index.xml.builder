# frozen_string_literal: true
xml.maintenanceincident(project: @project.name) do
  @maintenance_statistics.each do |maintenance_statistic|
    xml.entry(maintenance_statistic.to_hash_for_xml)
  end
end
