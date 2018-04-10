# frozen_string_literal: true
xml.packageresult('project' => @project, 'repository' => @repository,
                   'package' => @package) do
  xml.date(Time.now)
  xml.status('code' => @status) do
    xml.packagecount(@succeeded, 'state' => 'succeeded')
    xml.packagecount(@failed, 'state' => 'failed')
  end
  @arch_status.each do |a, s|
    xml.archresult('arch' => a) do
      xml.status('code' => s['code']) do
        xml.summary(s['summary']) if s['summary']
      end
      @arch_rpms[a].each do |r|
        xml.rpm('filename' => r)
      end
    end
  end
end
