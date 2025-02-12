class Workflow::Step::ConfigureRepositories < Workflow::Step
  REQUIRED_KEYS = %i[project repositories].freeze
  REQUIRED_REPOSITORY_KEYS = %i[architectures name paths].freeze
  REQUIRED_REPOSITORY_PATH_KEYS = %i[target_project target_repository].freeze

  validate :validate_repositories
  validate :validate_repository_paths
  validate :validate_architectures

  def call
    return if workflow_run.closed_merged_pull_request? || workflow_run.reopened_pull_request? || workflow_run.unlabeled_pull_request?
    return unless valid?

    configure_repositories
  end

  def configure_repositories
    target_project = Project.get_by_name(target_project_name)
    Pundit.authorize(@token.executor, target_project, :update?)

    step_instructions[:repositories].each do |repository_instructions|
      repository = Repository.includes(:architectures).find_or_create_by(name: repository_instructions[:name], project: target_project)

      repository_instructions[:paths].each do |repository_path|
        target_repository = Repository.find_by_project_and_name(repository_path[:target_project], repository_path[:target_repository])
        repository.path_elements.find_or_create_by(link: target_repository)
      end

      repository.repository_architectures.destroy_all

      repository_instructions[:architectures].uniq.each do |architecture_name|
        repository.architectures << @supported_architectures.select { |architecture| architecture.name == architecture_name }
      end
    end

    # We have to store the changes on the backend
    target_project.store(comment: "Added the following repositories to the project: #{step_instructions[:repositories].pluck(:name).compact.to_sentence}",
                         login: @token.executor.login)
  end

  private

  def target_project_base_name
    step_instructions[:project]
  end

  def validate_repositories
    return if step_instructions[:repositories].all? { |repository| repository.keys.sort == REQUIRED_REPOSITORY_KEYS }

    # FIXME: This is only to help users migrate their configure_repositories steps when we introduced this breaking change. Remove this after March 1st, 2022.
    if step_instructions[:repositories].any? { |repository| !repository.key?(:paths) }
      errors.add(:base,
                 "configure_repositories step: Repository paths are now set under the 'paths' key. Refer to " \
                 'https://openbuildservice.org/help/manuals/obs-user-guide/cha-obs-scm-ci-workflow-integration' \
                 '#sec-obs-obs-scm-ci-workflow-integration-obs-workflows-steps-configure-repositories-architectures-for-a-project for an example')
    end

    required_repository_keys_sentence ||= REQUIRED_REPOSITORY_KEYS.map { |key| "'#{key}'" }.to_sentence
    errors.add(:base, "configure_repositories step: All repositories must have the #{required_repository_keys_sentence} keys")
  end

  def validate_repository_paths
    repository_path_has_all_keys = ->(repository_path) { repository_path.keys.sort == REQUIRED_REPOSITORY_PATH_KEYS }
    return if step_instructions[:repositories].all? { |repository| repository.fetch(:paths, [{}]).all?(&repository_path_has_all_keys) }

    required_repository_path_keys_sentence ||= REQUIRED_REPOSITORY_PATH_KEYS.map { |key| "'#{key}'" }.to_sentence
    errors.add(:base, "configure_repositories step: All repository paths must have the #{required_repository_path_keys_sentence} keys")
  end

  def validate_architectures
    architectures = step_instructions[:repositories].map { |repository| repository.fetch(:architectures, []) }.flatten.uniq

    # Store architectures to avoid fetching them again later in #call
    @supported_architectures = Architecture.where(name: architectures).to_a

    return if @supported_architectures.size == architectures.size

    inexistent_architectures = architectures - @supported_architectures.map(&:name)

    return if inexistent_architectures.empty?

    inexistent_architectures_sentence ||= inexistent_architectures.map { |key| "'#{key}'" }.to_sentence
    errors.add(:base, "configure_repositories step: Architectures #{inexistent_architectures_sentence} do not exist")
  end
end
