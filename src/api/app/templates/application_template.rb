class ApplicationTemplate
  attr_accessor :files

  def initialize(subtemplate:, package:, user:)
    @package = package
    @user = user
    @subtemplate = subtemplate
    @files = []
  end

  def render(filename)
    file_path = path.join("#{filename}.erb")
    content = File.read(file_path)
    t = ERB.new(content)
    t.result(binding)
  end

  def partial(filename)
    render("_#{filename}")
  end

  def path
    basedir = self.class.name.underscore.gsub('_template', '')
    Rails.root.join("app/templates/#{basedir}/")
  end

  def uploaded_file(filename, content)
    tempfile = Tempfile.new
    tempfile.write(content)
    tempfile.close
    ActionDispatch::Http::UploadedFile.new(tempfile:, filename:)
  end
end
