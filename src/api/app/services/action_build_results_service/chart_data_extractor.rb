module ActionBuildResultsService
  class ChartDataExtractor
    attr_accessor :actions

    def initialize(actions:)
      @actions = actions
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    def call
      return [] if @actions.blank?

      @actions.where(type: %i[submit maintenance_incident maintenance_release]).filter_map do |action|
        sources = sources_from_action(action)
        next unless sources[:source_project].present? && sources[:source_package].present?

        source_build_results = package_build_results(sources[:source_package], sources[:source_project])

        targets = target_from_action(action) if BsRequest.find(action.bs_request_id).staging_project_id.nil?
        next source_build_results if targets.nil? || targets[:target_package].nil? || targets[:target_project].nil?

        target_build_results = package_build_results(targets[:target_package], targets[:target_project])
        sort_build_results(source_build_results, target_build_results)
      end.flatten
    end
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity

    private

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

    def target_from_action(action)
      target_project = Project.find(action.target_project_id)
      target_package = target_project.packages.find(action.target_package_id)

      { target_project: target_project, target_package: target_package }
    end

    def package_build_results(package, project)
      results = package.buildresult(project, show_all: true).results
      results.flat_map do |pkg, build_results|
        build_results.map do |result|
          {
            architecture: result.architecture,
            repository: result.repository,
            status: result.code,
            package_name: pkg,
            project_name: project.name,
            repository_status: result.state,
            is_repository_in_db: result.is_repository_in_db,
            details: result.details
          }
        end
      end
    end

    # Sort build results so that repositories matching the target project appear at the top of the list
    def sort_build_results(source_build_results, target_build_results)
      target_repos = target_build_results.pluck(:repository).uniq
      matching, non_matching = source_build_results.partition do |result|
        target_repos.include?(result[:repository])
      end
      matching_sorted = matching.sort_by { |r| r[:repository] }
      matching_sorted + non_matching
    end
  end
end
