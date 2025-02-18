# rubocop:disable Metrics/ClassLength
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
    when 'Workflow::Step::SubmitRequest'
      artifacts_for_submit_request(parsed_artifacts)
    when 'Workflow::Step::SetFlags'
      artifacts_for_set_flag(parsed_artifacts)
    end
  rescue JSON::ParserError, ActionController::UrlGenerationError => e
    Airbrake.notify(e, artifacts_per_step_id: artifacts_per_step.id)
    tag.li { concat("Could not display artifacts for #{step.split('::').last.titleize}") }
  end

  private

  def artifacts_for_set_flag(parsed_artifacts)
    capture do
      list_of_flags(parsed_artifacts[:flags])
    end
  end

  def list_of_flags(flags)
    flags.each do |flag|
      concat(flag_step_sentence(flag))
    end
  end

  def flag_step_sentence(flag)
    path_details = package_or_project_path(flag)

    tag.li do
      concat('Set flag ')
      concat(tag.b("#{flag[:type]} "))
      concat("#{flag[:status]}d")
      concat(' on ')
      concat(link_to(path_details[:text], path_details[:path]))
      concat(" for repository #{flag[:repository]}") if flag[:repository]
      concat(" and architecture #{flag[:architecture]}") if flag[:architecture]
      concat('.')
    end
  end

  def artifacts_for_submit_request(parsed_artifacts)
    capture do
      parsed_artifacts[:request_numbers_and_state].each do |key, request_number|
        request_path = helpers.request_show_path(number: request_number)
        concat(tag.li(link_to("Request #{request_number} -> #{key}", request_path)))
      end
    end
  end

  def package_or_project_path(flag)
    if flag[:package]
      {
        path: helpers.repositories_path(project: flag[:project], package: flag[:package]),
        text: "#{flag[:project]}/#{flag[:package]}"
      }
    else
      {
        path: helpers.project_repositories_path(project: flag[:project]),
        text: flag[:project].to_s
      }
    end
  end

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
      concat(link_to(parsed_artifacts[:project].to_s, project_path))
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
    concat(tag.span(repository[:name].to_s, class: 'fst-italic'))
    concat(' for architectures ')
    concat(tag.span(repository[:architectures].to_sentence.to_s, class: 'fst-italic'))
    concat(' for the paths: ')
    concat(tag.span(paths_sentence(repository).to_s, class: 'fst-italic'))
    concat('.')
  end

  def paths_sentence(repository)
    repository[:paths].map { |path| "#{path[:target_project]}/#{path[:target_repository]}" }.to_sentence
  end
end
# rubocop:enable Metrics/ClassLength
