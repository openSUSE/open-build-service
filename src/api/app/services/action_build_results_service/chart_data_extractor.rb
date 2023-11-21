module ActionBuildResultsService
  class ChartDataExtractor
    attr_accessor :actions, :raw_data

    def initialize(actions:)
      @actions = actions
      @raw_data = []
    end

    def call
      @actions.where(type: [:submit, :maintenance_incident, :maintenance_release])
              .map { |action| sources_from_action(action) }
              .select { |sources| sources[:source_project].present? && sources[:source_package].present? }
              .each do |sources|
        package_build_results = package_build_results(sources[:source_package], sources[:source_project])

        add_request_build_results(package_build_results, sources[:source_package], sources[:source_project])
      end

      @raw_data.flatten
    end

    private

    def add_request_build_results(package_build_results, source_package, source_project)
      @raw_data.push(
        package_build_results.map do |result_entry|
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

    def sources_from_action(action)
      source_project = project_from_action(action)
      source_package = source_project.present? ? Package.find_by_project_and_name(source_project.name, action.source_package) : nil
      { source_project: source_project, source_package: source_package }
    end

    def package_build_results(source_package, source_project)
      source_package.buildresult(source_project, show_all: true).results.flat_map { |_k, v| v }
    end
  end
end
