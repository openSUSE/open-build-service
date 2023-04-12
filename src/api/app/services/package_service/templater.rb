module PackageService
  class Templater
    def self.templates
      ApplicationTemplate.descendants.each_with_object({}) do |template, map|
        map[template.title] = template.subtemplates.map { |t| [t[1], "#{template.name}##{t[0]}"] }
      end
    end

    def initialize(package:, template:, subtemplate:)
      @package = package
      @template = ApplicationTemplate.descendants.find { |d| d.name == template }
      @subtemplate = subtemplate.to_sym if @template && @template.subtemplates.key?(subtemplate.to_sym)
    end

    def call
      files = @template.new(subtemplate: @subtemplate, package: @package, user: User.session).files
      FileService::Uploader.new(@package, files, 'Created from a template').call
    end
  end
end
