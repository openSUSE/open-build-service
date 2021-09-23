class Workflow::Step::ConfigureRepositories < Workflow::Step
  REQUIRED_KEYS = [:project, :repositories].freeze
  REQUIRED_REPOSITORY_KEYS = [:architectures, :name, :target_project, :target_repository].freeze

  validate :validate_repositories
  validate :validate_architectures

  def call(_options = {})
    return unless valid?

    target_project = Project.get_by_name(target_project_name)
    Pundit.authorize(@token.user, target_project, :update?)

    step_instructions[:repositories].each do |repository_instructions|
      repository = Repository.includes(:architectures).find_or_create_by(name: repository_instructions[:name], project: target_project)

      target_repository = Repository.find_by_project_and_name(repository_instructions[:target_project], repository_instructions[:target_repository])
      repository.path_elements.find_or_create_by(link: target_repository)

      repository.repository_architectures.destroy_all

      repository_instructions[:architectures].uniq.each do |architecture_name|
        repository.architectures << @supported_architectures.select { |architecture| architecture.name == architecture_name }
      end
    end
  end

  def project_name
    step_instructions[:project]
  end

  # This method needs to be public because it is used in the Workflow model.
  def target_project_name
    if scm_webhook.pull_request_event?
      case scm_webhook.payload[:scm]
      when 'github'
        "#{project_name}:#{scm_webhook.payload[:target_repository_full_name]}:PR-#{scm_webhook.payload[:pr_number]}".tr('/', '-')
      when 'gitlab'
        "#{project_name}:#{scm_webhook.payload[:path_with_namespace]}:PR-#{scm_webhook.payload[:pr_number]}".tr('/', '-')
      end
    elsif scm_webhook.push_event?
      project_name
    end
  end

  private

  def validate_repositories
    return if step_instructions[:repositories].all? { |repository| repository.keys.sort == REQUIRED_REPOSITORY_KEYS }

    required_repository_keys_sentence ||= REQUIRED_REPOSITORY_KEYS.map { |key| "'#{key}'" }.to_sentence
    errors.add(:base, "configure_repositories step: All repositories must have the #{required_repository_keys_sentence} keys")
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
