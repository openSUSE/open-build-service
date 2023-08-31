# rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
class ChartComponent < ApplicationComponent
  attr_reader :actions

  def initialize(actions:)
    super

    @actions = actions
  end

  def build_results_chart_data
    success = {}
    failed = {}
    building = {}
    refused = {}

    # take all the build results for all the actions (only actions where it makes sense to have a build status)
    @actions.where(type: [:submit, :maintenance_incident, :maintenance_release]).each do |action|
      src_prj_obj = Project.find_by_name(action.source_project)
      src_pkg_obj = Package.find_by_project_and_name(src_prj_obj.name, action.source_package)

      # fetch all build results for the source package
      action_build_results = src_pkg_obj.buildresult(src_prj_obj, show_all: true).results[src_pkg_obj.name]

      next unless action_build_results

      action_build_results.each do |result_entry|
        final_status = Buildresult.new(result_entry.code)
        key = result_entry.repository

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
    end

    # no build results available
    return nil if success.empty? && failed.empty? && building.empty? && refused.empty?

    # collect all the datasets
    [
      { name: 'Published' }.merge({ data: success }),
      { name: 'Failed' }.merge({ data: failed }),
      { name: 'Building' }.merge({ data: building }),
      { name: 'Excluded' }.merge({ data: refused })
    ]
  end
end

# rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
