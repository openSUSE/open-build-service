# frozen_string_literal: true
xml.projectresult('project' => @project) do
  xml.date(Time.now)
  xml.status('code' => @status) do
    xml.packagecount(@succeeded, 'state' => 'succeeded')
    xml.packagecount(@rpms, 'state' => 'rpms')
    xml.packagecount(@building, 'state' => 'building')
    xml.packagecount(@delayed, 'state' => 'delayed')
  end
  @repository_status.each do |r, arch_status|
    xml.repositoryresult('name' => r) do
      arch_status.each do |a, s|
        xml.archresult('arch' => a) do
          xml.status('code' => s)
        end
      end
    end
  end
end
