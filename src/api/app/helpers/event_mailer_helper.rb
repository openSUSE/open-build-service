module EventMailerHelper
  def project_or_package_text(project, package, opts = {})
    if package.present?
      text="#{project}/#{package}"
    else
      text=project
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
