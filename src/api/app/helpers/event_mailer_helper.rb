module EventMailerHelper
  def project_or_package_text(project, package, opts = {})
    text = if package.present?
      "#{project}/#{package}"
    else
      project
    end
    if opts[:short].nil?
      if package.present?
	"package #{text}"
      else
        "project #{text}"
      end
    end
  end
end
