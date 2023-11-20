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

    def push_build_results_entries(action_build_results, source_package, source_project)
      return unless action_build_results

      @raw_data.push(
        action_build_results.map do |result_entry|
          {
            architecture: result_entry.architecture,
            repository: result_entry.repository,
            status: result_entry.code,
            package_name: source_package.name,
            project_name: source_project.name
          }
        end
      )
    end

    def project_from_action(action)
      bs_request = BsRequest.find(action.bs_request_id)
      # consider staging project
      project_name = bs_request.staging_project_id.nil? ? action.source_project : bs_request.staging_project.name
      Project.find_by_name(project_name)
    end

    def fill_action_build_results(source_package, source_project)
      source_package.buildresult(source_project, show_all: true).results.flat_map { |_k, v| v }
    end

    def fill_raw_data
      @actions.where(type: [:submit, :maintenance_incident, :maintenance_release]).find_each do |action|
        source_project = project_from_action(action)

        if source_project
          source_package = Package.find_by_project_and_name(source_project.name, action.source_package)
          if source_package
            action_build_results = fill_action_build_results(source_package, source_project)

            # carry over and expose relevant information
            push_build_results_entries(action_build_results, source_package, source_project)
          end
        end
      end
    end
  end
end
