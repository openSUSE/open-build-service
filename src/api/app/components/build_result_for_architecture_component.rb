class BuildResultForArchitectureComponent < ApplicationComponent
  attr_accessor :result, :project, :package

  def initialize(result, project, package)
    super

    @result = result
    @project = project
    @package = package
  end

  private

  def result_code
    result.code
  end

  def help
    help = "<p><strong>Package build ( #{build_status_icon} #{result_code} ):</strong> #{build_status_help}</p>"
    help += "<p><u>Details</u>: #{build_status_details}</p>" if build_status_details.present?
    help += "<p><strong>Repository status ( #{repository_status_icon} #{result.state} ): </strong>#{repository_status_help}</p>"
    help
  end

  def build_status_help
    Buildresult.status_description(result_code)
  end

  def build_status_details
    result.details
  end

  def repository_status_help
    result.is_repository_in_db ? helpers.repository_info(result.state) : 'This result is outdated'
  end

  def build_status_icon_with_link
    return build_status_icon if result_code.in?(['-', 'unresolvable', 'blocked', 'excluded', 'scheduled'])

    link_to(package_live_build_log_path(project: project.to_s, package: package,
                                        repository: result.repository, arch: result.architecture), rel: 'nofollow') do
      capture { build_status_icon }
    end
  end

  def build_status_icon
    tag.i(class: "fa #{helpers.build_status_icon(result_code)} text-gray-500")
  end

  def repository_status_icon
    helpers.repository_status_icon(status: result.state)
  end

  def status_border_color(status)
    build_result = Buildresult.new(status)
    return 'border-warning' if build_result.in_progress_status?
    return 'border-success' if build_result.successful_final_status?
    return 'border-danger' if build_result.unsuccessful_final_status?
    return 'border-gray-300' if build_result.refused_status?
  end

  def build_status
    return result_code if result_code.in?(['-', 'unresolvable', 'blocked', 'excluded', 'scheduled'])

    link_to(result_code, package_live_build_log_path(project: project.to_s, package: package,
                                                     repository: result.repository, arch: result.architecture), rel: 'nofollow')
  end
end
