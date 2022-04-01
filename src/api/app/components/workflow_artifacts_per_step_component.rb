class WorkflowArtifactsPerStepComponent < ApplicationComponent
  with_collection_parameter :artifacts_per_step

  attr_reader :artifacts_per_step, :step, :artifacts

  def initialize(artifacts_per_step:)
    super
    @artifacts_per_step = artifacts_per_step
    @step = @artifacts_per_step.step
    @artifacts = @artifacts_per_step.artifacts
  end

  def call
    parsed_artifacts = JSON.parse(artifacts).deep_symbolize_keys

    case step
    when 'Workflow::Step::BranchPackageStep'
      artifacts_for_branch_or_link_package(parsed_artifacts, 'Branched package from ')
    when 'Workflow::Step::LinkPackageStep'
      artifacts_for_branch_or_link_package(parsed_artifacts, 'Linked package from ')
    when 'Workflow::Step::RebuildPackage'
      artifacts_for_rebuild_or_trigger_package(parsed_artifacts, 'Rebuilt package ')
    when 'Workflow::Step::TriggerServices'
      artifacts_for_rebuild_or_trigger_package(parsed_artifacts, 'Triggered services on package ')
    when 'Workflow::Step::ConfigureRepositories'
      artifacts_for_configure_repositories(parsed_artifacts)
    end
  rescue JSON::ParserError, ActionController::UrlGenerationError => e
    Airbrake.notify(e, artifacts_per_step_id: artifacts_per_step.id)
    tag.li { concat("Could not display artifacts for #{step.split('::').last.titleize}") }
  end

  private

  def artifacts_for_branch_or_link_package(parsed_artifacts, label)
    source_path = helpers.package_show_path(project: parsed_artifacts[:source_project], package: parsed_artifacts[:source_package])
    target_path = helpers.package_show_path(project: parsed_artifacts[:target_project], package: parsed_artifacts[:target_package])

    tag.li do
      concat(label)
      concat(link_to("#{parsed_artifacts[:source_project]}/#{parsed_artifacts[:source_package]}", source_path))
      concat(' to ')
      concat(link_to("#{parsed_artifacts[:target_project]}/#{parsed_artifacts[:target_package]}", target_path))
      concat('.')
    end
  end

  def artifacts_for_rebuild_or_trigger_package(parsed_artifacts, label)
    package_path = helpers.package_show_path(project: parsed_artifacts[:project], package: parsed_artifacts[:package])

    tag.li do
      concat(label)
      concat(link_to("#{parsed_artifacts[:project]}/#{parsed_artifacts[:package]}", package_path))
      concat('.')
    end
  end

  def artifacts_for_configure_repositories(parsed_artifacts)
    project_path = helpers.project_show_path(project: parsed_artifacts[:project])
    repositories_path = helpers.project_repositories_path(parsed_artifacts[:project])
    tag.li do
      concat('Configured ')
      concat(link_to('repositories', repositories_path))
      concat(' on project ')
      concat(link_to("#{parsed_artifacts[:project]}", project_path))
      concat(': ')
      concat(list_of_repositories(parsed_artifacts[:repositories]))
    end
  end

  def list_of_repositories(repositories)
    tag.ul do
      repositories.each do |repository|
        concat(tag.li { repository_sentence(repository) })
      end
    end
  end

  def repository_sentence(repository)
    concat(tag.span("#{repository[:name]}", class: 'font-italic'))
    concat(' for architectures ')
    concat(tag.span("#{repository[:architectures].to_sentence}", class: 'font-italic'))
    concat(' for the paths: ')
    concat(tag.span("#{paths_sentence(repository)}", class: 'font-italic'))
    concat('.')
  end

  def paths_sentence(repository)
    repository[:paths].map { |path| "#{path[:target_project]}/#{path[:target_repository]}" }.to_sentence
  end
end
