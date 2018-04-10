# frozen_string_literal: true

xml.package('name' => @package.name) do
  xml.title @package.title
  xml.description @package.description
  @package.each_person do |p|
    xml.person('userid' => p.userid, 'role' => p.role)
  end
end
