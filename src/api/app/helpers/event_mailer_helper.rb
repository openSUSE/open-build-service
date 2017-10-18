module EventMailerHelper
  def project_or_package_text(project, package)
    return "package #{project}/#{package}" if package.present?
    "project #{project}"
  end
end
