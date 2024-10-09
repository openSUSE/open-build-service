module PackageService
  class Templater
    include ActiveModel::Model

    attr_accessor :package, :template

    validates :package, :template, presence: true

    def self.templates
      Project.package_templates.each_with_object({}) do |project, map|
        map[project.title.presence || project.name] = project.packages.map { |p| [p.title.presence || p.name, "#{project.to_param}/#{p.to_param}"] }
      end
    end

    def call
      FileService::Uploader.new(@package, files, 'Created from a template').call
    end

    private

    def files
      @template.dir_hash.elements('entry').map do |file|
        template_contents = @template.source_file(file['name'])
        return uploaded_file(file['name'], template_contents) unless file['name'].end_with?('.liquid')

        filename = render_liquid_string(file['name'].delete_suffix('.liquid'))
        contents = render_liquid_string(template_contents)
        uploaded_file(filename, contents)
      end
    end

    def uploaded_file(filename, contents)
      tempfile = Tempfile.new.tap do |t|
        t.write(contents)
        t.close
      end

      ActionDispatch::Http::UploadedFile.new(tempfile:, filename:)
    end

    def render_liquid_string(string)
      template = Liquid::Template.parse(string)
      template.render(template_options)
    end

    def template_options
      { 'project' => PackageService::Templater::ProjectDrop.new(@package.project),
        'package' => PackageService::Templater::PackageDrop.new(@package),
        'user' => PackageService::Templater::UserDrop.new(User.session!) }
    end
  end
end
