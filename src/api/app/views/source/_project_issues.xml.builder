# frozen_string_literal: true

xml.project(name: @project.name) do
  @project.packages.each do |pkg|
    xml.package(project: @project.name, name: pkg.name) do
      render partial: 'common_issues', locals: { builder: xml, issues: pkg.package_issues }
    end
  end
end
