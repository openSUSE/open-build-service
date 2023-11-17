class ChartComponent < ApplicationComponent
  attr_reader :actions

  def initialize(actions:)
    super

    @actions = actions
  end

  def build_results_data
    raw_data = []

    # take all the build results for all the actions (only actions where it makes sense to have a build status)
    @actions.where(type: [:submit, :maintenance_incident, :maintenance_release]).find_each do |action|
      src_prj_obj = project_from_action(action)

      # skip if project not found
      next unless src_prj_obj

      src_pkg_obj = Package.find_by_project_and_name(src_prj_obj.name, action.source_package)

      # the package might not exist yet in the staging project, for instance
      next unless src_pkg_obj

      # fetch all build results for the source package (considering multibuild packages as well)
      action_build_results = src_pkg_obj.buildresult(src_prj_obj, show_all: true).results.flat_map { |_k, v| v }

      next unless action_build_results

      # carry over and expose relevant information
      raw_data.push(build_results_entries(action_build_results, src_pkg_obj, src_prj_obj))
    end

    raw_data.flatten
  end

  def chart_data(raw_data)
    success = Hash.new(0)
    failed = Hash.new(0)
    building = Hash.new(0)
    refused = Hash.new(0)

    # reshape data in subsets to feed the chart
    # shape of each dataset: {repository name, build count occurrencies}
    raw_data.each do |result_entry|
      final_status = Buildresult.new(result_entry[:status])
      key = result_entry[:repository]

      if final_status.successful_final_status? # success results
        success[key] += 1
      elsif final_status.unsuccessful_final_status? # failed results
        failed[key] += 1
      elsif final_status.in_progress_status? # in progress results
        building[key] += 1
      elsif final_status.refused_status? # non building results
        refused[key] += 1
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

  def distinct_repositories(raw_data)
    raw_data.pluck(:repository).to_set
  end

  def status_color(status)
    build_result = Buildresult.new(status)
    return 'text-bg-success' if build_result.successful_final_status?
    return 'text-bg-danger' if build_result.unsuccessful_final_status?
    return 'text-bg-warning' if build_result.in_progress_status?

    'bg-light text-dark border border-1' if build_result.refused_status?
  end

  def legend
    content_tag(:div, 'Published', class: 'text-bg-success ps-2 pe-2 m-1').concat(
      content_tag(:div, 'Failed', class: 'text-bg-danger ps-2 pe-2 m-1').concat(
        content_tag(:div, 'Building', class: 'text-bg-warning ps-2 pe-2 m-1').concat(
          content_tag(:div, 'Excluded', class: 'bg-light text-dark border border-1 ps-2 pe-2 m-1')
        )
      )
    )
  end

  private

  def build_results_entries(action_build_results, src_pkg_obj, src_prj_obj)
    action_build_results.map do |result_entry|
      {
        architecture: result_entry.architecture,
        repository: result_entry.repository,
        status: result_entry.code,
        package_name: src_pkg_obj.name,
        project_name: src_prj_obj.name
      }
    end
  end

  def project_from_action(action)
    bs_request = BsRequest.find(action.bs_request_id)
    # consider staging project
    prj_name = bs_request.staging_project_id.nil? ? action.source_project : bs_request.staging_project.name
    Project.find_by_name(prj_name)
  end
end
