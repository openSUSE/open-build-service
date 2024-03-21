# This component renders the request action description based on the type of the action

class BsRequestActionDescriptionComponent < ApplicationComponent
  attr_reader :action

  delegate :project_or_package_link, to: :helpers
  delegate :user_with_realname_and_icon, to: :helpers
  delegate :requester_str, to: :helpers
  delegate :creator_intentions, to: :helpers

  def initialize(action:, creator:)
    super
    @action = action
    @creator = creator
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Rails/OutputSafety
  # rubocop:disable Style/FormatString
  def description
    source_project_hash = { project: action[:sprj], package: action[:spkg], trim_to: nil }

    description = case action[:type]
                  when :submit
                    'Submit %{source_container} to %{target_container}' % {
                      source_container: project_or_package_link(source_project_hash),
                      target_container: project_or_package_link(project: action[:tprj], package: action[:tpkg])
                    }
                  when :delete
                    target_repository = "repository #{link_to(action[:trepo], repositories_path(project: action[:tprj], repository: action[:trepo]))} for " if action[:trepo]

                    'Delete %{target_repository}%{target_container}' % {
                      target_repository: target_repository,
                      target_container: project_or_package_link(project: action[:tprj], package: action[:tpkg])
                    }
                  when :add_role, :set_bugowner
                    '%{creator} wants %{requester} to %{task} for %{target_container}' % {
                      creator: user_with_realname_and_icon(@creator),
                      requester: requester_str(@creator, action[:user], action[:group]),
                      task: creator_intentions(action[:role]),
                      target_container: project_or_package_link(project: action[:tprj], package: action[:tpkg])
                    }
                  when :change_devel
                    'Set %{source_container} to be devel project/package of %{target_container}' % {
                      source_container: project_or_package_link(source_project_hash),
                      target_container: project_or_package_link(project: action[:tprj], package: action[:tpkg])
                    }
                  when :maintenance_incident
                    source_project_hash.update(homeproject: @creator)
                    'Submit update from %{source_container} to %{target_container}' % {
                      source_container: project_or_package_link(source_project_hash),
                      target_container: project_or_package_link(project: action[:tprj], package: action[:tpkg], trim_to: nil)
                    }
                  when :maintenance_release
                    'Maintenance release %{source_container} to %{target_container}' % {
                      source_container: project_or_package_link(source_project_hash),
                      target_container: project_or_package_link(project: action[:tprj], package: action[:tpkg], trim_to: nil)
                    }
                  when :release
                    'Release %{source_container} to %{target_container}' % {
                      source_container: project_or_package_link(source_project_hash),
                      target_container: project_or_package_link(project: action[:tprj], package: action[:tpkg])
                    }
                  end

    description.html_safe
  end
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Rails/OutputSafety
  # rubocop:enable Style/FormatString
end
