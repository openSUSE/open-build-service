module EventMailerHelper
  def project_or_package_text(project, package, opts = {})
    if package.present?
      text = "#{project}/#{package}"
    else
      text = project
    end

    return unless opts[:short].nil?
    return "package #{text}" if package.present?

    "project #{text}"
  end
end
