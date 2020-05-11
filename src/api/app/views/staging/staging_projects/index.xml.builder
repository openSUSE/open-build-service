xml.staging_projects do
  @staging_projects.each do |staging_project|
    render(partial: 'staging_project_item', locals: { staging_project: staging_project, options: @options, builder: xml })
  end
end
