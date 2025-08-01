class BuildresultStatusLinkComponent < ApplicationComponent
  def initialize(repository_name:, architecture_name:, project_name:, package_name:, build_status:, build_details:)
    super

    @repository_name = repository_name
    @architecture_name = architecture_name
    @project_name = project_name
    @package_name = package_name
    @build_details = build_details
    @build_status = build_status
  end

  def show_link?
    ['-', 'unresolvable', 'blocked', 'excluded', 'scheduled'].exclude?(@build_status)
  end

  def css_class
    # special case for scheduled jobs with constraints limiting the workers a lot
    return 'text-warning' if @build_status == 'scheduled' && @build_details.present?

    "build-state-#{@build_status}" if @build_status.present?
  end

  def span_id
    "id-#{@package_name}_#{@repository_name}_#{@architecture_name}"
  end
end
