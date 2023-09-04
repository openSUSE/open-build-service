class ChartComponent < ApplicationComponent
  attr_reader :actions

  def initialize(actions:)
    super

    @actions = actions
  end

  def build_results_data
    raw_data = []

    # take all the build results for all the actions (only actions where it makes sense to have a build status)
    @actions.where(type: [:submit, :maintenance_incident, :maintenance_release]).each do |action|
      bs_request = BsRequest.find(action.bs_request_id)
      # consider staging project
      prj_name = bs_request.staging_project_id.nil? ? action.source_project : bs_request.staging_project.name
      src_prj_obj = Project.find_by_name(prj_name)
      src_pkg_obj = Package.find_by_project_and_name(src_prj_obj.name, action.source_package)

      # the package might not exist yet in the staging project, for instance
      next unless src_pkg_obj

      # fetch all build results for the source package (considering multibuild packages as well)
      action_build_results = src_pkg_obj.buildresult(src_prj_obj, show_all: true).results.flat_map { |_k, v| v }

      next unless action_build_results

      # carry over and expose relevant information
      raw_data.push(
        action_build_results.map do |result_entry|
          {
            architecture: result_entry.architecture,
            repository: result_entry.repository,
            status: result_entry.code,
            package_name: src_pkg_obj.name,
            project_name: src_prj_obj.name
          }
        end
      )
    end

    raw_data.flatten
  end

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def chart_data(raw_data)
    success = {}
    failed = {}
    building = {}
    refused = {}

    # reshape data in subsets to feed the chart
    # shape of each dataset: {repository name, build count occurrencies}
    raw_data.each do |result_entry|
      final_status = Buildresult.new(result_entry[:status])
      key = result_entry[:repository]

      if final_status.successful_final_status? # success results
        success[key] ? success.store(key, success[key] + 1) : success.store(key, 1)
      elsif final_status.unsuccessful_final_status? # failed results
        failed[key] ? failed.store(key, failed[key] + 1) : failed.store(key, 1)
      elsif final_status.in_progress_status? # in progress results
        building[key] ? building.store(key, building[key] + 1) : building.store(key, 1)
      elsif final_status.refused_status? # non building results
        refused[key] ? refused.store(key, refused[key] + 1) : refused.store(key, 1)
      end
    end

    # collect all the datasets
    [
      { name: 'Published' }.merge({ data: success }),
      { name: 'Failed' }.merge({ data: failed }),
      { name: 'Building' }.merge({ data: building }),
      { name: 'Excluded' }.merge({ data: refused })
    ]
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def distinct_repositories(raw_data)
    raw_data.pluck(:repository).to_set
  end

  def status_color(status)
    build_result = Buildresult.new(status)
    return 'bg-success text-light' if build_result.successful_final_status?
    return 'bg-danger text-light' if build_result.unsuccessful_final_status?
    return 'bg-warning text-dark' if build_result.in_progress_status?

    'bg-light text-dark border border-1' if build_result.refused_status?
  end

  def legend
    content_tag(:div, 'Published', class: 'bg-success text-light ps-2 pe-2 m-1').concat(
      content_tag(:div, 'Failed', class: 'bg-danger text-light ps-2 pe-2 m-1').concat(
        content_tag(:div, 'Building', class: 'bg-warning text-dark ps-2 pe-2 m-1').concat(
          content_tag(:div, 'Excluded', class: 'bg-light text-dark border border-1 ps-2 pe-2 m-1')
        )
      )
    )
  end
end
