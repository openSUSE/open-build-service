module ActionBuildResultsService
  class ChartDataExtractor
    attr_accessor :actions, :raw_data

    def initialize(actions:)
      @actions = actions
      @raw_data = []
    end

    def call
      fill_raw_data

      @raw_data.flatten
    end

    private

    def push_build_results_entries(action_build_results, src_pkg_obj, src_prj_obj)
      @raw_data.push(
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

    def project_from_action(action)
      bs_request = BsRequest.find(action.bs_request_id)
      # consider staging project
      prj_name = bs_request.staging_project_id.nil? ? action.source_project : bs_request.staging_project.name
      Project.find_by_name(prj_name)
    end

    def fill_action_build_results(src_pkg_obj, src_prj_obj)
      src_pkg_obj.buildresult(src_prj_obj, show_all: true).results.flat_map { |_k, v| v }
    end

    def fill_raw_data
      @actions.where(type: [:submit, :maintenance_incident, :maintenance_release]).find_each do |action|
        # skip if project not found
        next unless (src_prj_obj = project_from_action(action))

        # the package might not exist yet in the staging project, for instance
        next unless (src_pkg_obj = Package.find_by_project_and_name(src_prj_obj.name, action.source_package))

        # fetch all build results for the source package (considering multibuild packages as well)
        next unless (action_build_results = fill_action_build_results(src_pkg_obj, src_prj_obj))

        # carry over and expose relevant information
        push_build_results_entries(action_build_results, src_pkg_obj, src_prj_obj)
      end
    end
  end
end
