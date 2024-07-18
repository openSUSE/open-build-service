# This component renders the request action description based on the type of the action

class BsRequestActionDescriptionComponent < ApplicationComponent
  attr_reader :action

  delegate :project_or_package_link, to: :helpers
  delegate :user_with_realname_and_icon, to: :helpers
  delegate :requester_str, to: :helpers
  delegate :creator_intentions, to: :helpers

  def initialize(action:)
    super
    @action = action
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Rails/OutputSafety
  # rubocop:disable Style/FormatString
  def description
    creator = action.bs_request.creator
    source_project_hash = { project: action.source_project, package: action.source_package, trim_to: nil }
    target_project_hash = { project: action.target_project, package: action.target_package, trim_to: nil }

    source_container = project_or_package_link(source_project_hash)
    target_container = project_or_package_link(target_project_hash)

    description = case action.type
                  when 'submit'
                    'Submit %{source_container} to %{target_container}' %
                    { source_container: source_container, target_container: target_container }
                  when 'delete'
                    target_repository = "repository #{link_to(action.target_repository, repositories_path(target_project_hash))} for " if action.target_repository

                    'Delete %{target_repository}%{target_container}' %
                    { target_repository: target_repository, target_container: target_container }
                  when 'add_role', 'set_bugowner'
                    '%{creator} wants %{requester} to %{task} for %{target_container}' % {
                      creator: user_with_realname_and_icon(creator),
                      requester: requester_str(creator, action.person_name, action.group_name),
                      task: creator_intentions(action.role),
                      target_container: target_container
                    }
                  when 'change_devel'
                    'Set %{source_container} to be devel project/package of %{target_container}' %
                    { source_container: source_container, target_container: target_container }
                  when 'maintenance_incident'
                    'Submit update from %{source_container} to %{target_container}' %
                    { source_container: source_container, target_container: target_container }
                  when 'maintenance_release'
                    'Maintenance release %{source_container} to %{target_container}' %
                    { source_container: source_container, target_container: target_container }
                  when 'release'
                    'Release %{source_container} to %{target_container}' %
                    { source_container: source_container, target_container: target_container }
                  end

    # HACK: this is just a porting of the already existing way of passing the string to the view
    # TODO: refactor in order to get rid of the `html_safe` tagging
    description.html_safe
  end
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Rails/OutputSafety
  # rubocop:enable Style/FormatString
end
