module Webui::RpmlintHelper
  def lint_description(lint)
    path = Rails.root.join('tmp/rpmlint/descriptions.yaml')
    descriptions = File.exist?(path) ? YAML.load_file(path) : {}

    descriptions[lint]
  end
end
