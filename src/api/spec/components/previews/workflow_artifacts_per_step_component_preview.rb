class WorkflowArtifactsPerStepComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/workflow_artifacts_per_step_component/with_branch_package_step
  def with_branch_package_step
    step = Workflow::Step::BranchPackageStep.new(branch_or_link_package_parameters)
    render_artifacts_per_step(step, branch_or_link_package_artifacts(step))
  end

  # Preview at http://HOST:PORT/rails/view_components/workflow_artifacts_per_step_component/with_link_package_step
  def with_link_package_step
    step = Workflow::Step::LinkPackageStep.new(branch_or_link_package_parameters)
    render_artifacts_per_step(step, branch_or_link_package_artifacts(step))
  end

  # Preview at http://HOST:PORT/rails/view_components/workflow_artifacts_per_step_component/with_rebuild_package_step
  def with_rebuild_package_step
    step = Workflow::Step::RebuildPackage.new(rebuild_package_or_trigger_services_parameters)
    artifacts = step.step_instructions.to_json
    render_artifacts_per_step(step, artifacts)
  end

  # Preview at http://HOST:PORT/rails/view_components/workflow_artifacts_per_step_component/with_trigger_services_step
  def with_trigger_services_step
    step = Workflow::Step::TriggerServices.new(rebuild_package_or_trigger_services_parameters)
    artifacts = step.step_instructions.to_json
    render_artifacts_per_step(step, artifacts)
  end

  # Preview at http://HOST:PORT/rails/view_components/workflow_artifacts_per_step_component/with_configure_repositories_step
  def with_configure_repositories_step
    step = Workflow::Step::ConfigureRepositories.new({
                                                       step_instructions: {
                                                         project: 'OBS:Server:Unstable',
                                                         repositories: [
                                                           {
                                                             name: 'openSUSE_Tumbleweed',
                                                             paths: [{ target_project: 'openSUSE:Factory', target_repository: 'snapshot' },
                                                                     { target_project: 'devel:tools', target_repository: 'openSUSE_Factory_ARM' }],
                                                             architectures: %w[x86_64 ppc]
                                                           },
                                                           {
                                                             name: 'openSUSE_Leap_15.3',
                                                             paths: [{ target_project: 'openSUSE:Leap:15.3', target_repository: 'standard' }],
                                                             architectures: ['x86_64']
                                                           }
                                                         ]
                                                       },
                                                       workflow_run: workflow_run,
                                                       token: token
                                                     })

    artifacts = {
      project: step.target_project_name,
      repositories: step.step_instructions[:repositories]
    }.to_json

    render_artifacts_per_step(step, artifacts)
  end

  private

  def token
    Token.first
  end

  def workflow_run
    WorkflowRun.first
  end

  def rebuild_package_or_trigger_services_parameters
    {
      step_instructions: {
        project: 'OBS:Server:Unstable',
        package: 'obs-server'
      },
      workflow_run: workflow_run,
      token: token
    }
  end

  def branch_or_link_package_parameters
    {
      step_instructions: {
        source_project: 'OBS:Server:Unstable',
        source_package: 'obs-server',
        target_project: 'OBS:Server:Unstable:CI'
      },
      workflow_run: workflow_run,
      token: token
    }
  end

  def branch_or_link_package_artifacts(step)
    {
      source_project: step.step_instructions[:source_project],
      source_package: step.step_instructions[:source_package],
      target_project: step.target_project_name,
      target_package: step.target_package_name
    }.to_json
  end

  def render_artifacts_per_step(step, artifacts)
    artifacts_per_step = WorkflowArtifactsPerStep.new(workflow_run: workflow_run, artifacts: artifacts, step: step.class.name)
    render(WorkflowArtifactsPerStepComponent.new(artifacts_per_step: artifacts_per_step))
  end
end
