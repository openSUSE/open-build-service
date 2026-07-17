Rails.application.configure do
  # Preview classes of view components live in:
  config.view_component.previews.paths << Rails.root.join('spec/components/previews')
  # Set the default layout for previews (app/views/layouts/NAME.html.haml)
  config.view_component.previews.default_layout = 'view_component_previews'
  # Below the preview, display a syntax highlighted source code example of the usage of the view component
  config.view_component.show_previews_source = true
end

