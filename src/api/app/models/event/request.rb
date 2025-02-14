module Event
  class Request < Base
    include EventObjectRequest

    self.description = 'Request updated'
    self.abstract_class = true
    payload_keys :author, :comment, :description, :id, :number, :actions, :state, :when, :who, :namespace
    shortenable_key :description

    DIFF_LIMIT = 120

    def subject
      raise AbstractMethodCalled
    end

    def self.message_number(number)
      "<obs-request-#{number}@#{URI.parse(Configuration.obs_url).host.downcase}>"
    end

    def my_message_number
      Event::Request.message_number(payload['number'])
    end

    def originator
      payload_address('who')
    end

    def custom_headers
      mid = my_message_number
      h = super
      h['In-Reply-To'] = mid
      h['References'] = mid
      h['X-OBS-Request-Creator'] = payload['author']
      h['X-OBS-Request-Id'] = payload['number']
      h['X-OBS-Request-State'] = payload['state']

      h.merge(headers_for_actions)
    end

    def review_headers
      return { 'X-OBS-Review-By_User' => payload['by_user'] } if payload['by_user']
      return { 'X-OBS-Review-By_Group' => payload['by_group'] } if payload['by_group']
      return { 'X-OBS-Review-By_Package' => "#{payload['by_project']}/#{payload['by_package']}" } if payload['by_package']

      { 'X-OBS-Review-By_Project' => payload['by_project'] }
    end

    def actions_summary
      ret = []
      payload.with_indifferent_access['actions'][0..BsRequest::ACTION_NOTIFY_LIMIT].each do |a|
        str = "#{a['type']} #{a['targetproject']}"
        str += "/#{a['targetpackage']}" if a['targetpackage']
        str += "/#{a['targetrepository']}" if a['targetrepository']
        ret << str
      end
      ret.join(', ')
    end

    def payload_with_diff
      return payload if source_from_remote? || payload_without_source_project? || payload_without_target_project?

      ret = payload
      payload['actions'].each do |a|
        diff = calculate_diff(a).try(:lines)
        next unless diff

        diff_length = diff.length
        if diff_length > DIFF_LIMIT
          diff = diff[0..DIFF_LIMIT]
          diff << "[cut #{diff_length - DIFF_LIMIT} lines to limit mail size]"
        end
        a['diff'] = diff.join
      end
      ret
    end

    def reviewers
      BsRequest.find_by_number(payload['number']).reviews.map(&:users_and_groups_for_review).flatten.uniq
    end

    def creators
      [User.find_by_login(payload['author'])]
    end

    def target_maintainers
      action_maintainers('targetproject', 'targetpackage')
    end

    def source_maintainers
      action_maintainers('sourceproject', 'sourcepackage')
    end

    def source_project_watchers
      source_or_target_project_watchers(project_type: 'sourceproject')
    end

    def target_project_watchers
      source_or_target_project_watchers(project_type: 'targetproject')
    end

    def source_package_watchers
      source_or_target_package_watchers(project_type: 'sourceproject', package_type: 'sourcepackage')
    end

    def target_package_watchers
      source_or_target_package_watchers(project_type: 'targetproject', package_type: 'targetpackage')
    end

    def involves_hidden_project?
      bs_request = BsRequest.find_by(number: payload['number'])
      return false unless bs_request

      bs_request.bs_request_actions.any?(&:involves_hidden_project?)
    end

    private

    def source_or_target_project_watchers(project_type:)
      watchers = payload['actions'].pluck(project_type)
                                   .filter_map { |project_name| Project.find_by_name(project_name) }
                                   .map(&:watched_items)
                                   .flatten.map(&:user)
      watchers.uniq
    end

    def source_or_target_package_watchers(project_type:, package_type:)
      payload['actions'].map { |action| [action[project_type], action[package_type]] }
                        .filter_map do |project_name, package_name|
        next if project_name.blank? || package_name.blank?

        Package.get_by_project_and_name(project_name,
                                        package_name,
                                        { follow_multibuild: true, follow_project_links: false, use_source: false })
      rescue Package::Errors::UnknownObjectError, Project::Errors::UnknownObjectError
        nil
      end
                        .map(&:watched_items)
                        .flatten.map(&:user)
    end

    def action_maintainers(prjname, pkgname)
      payload['actions'].map do |action|
        _roles('maintainer', action[prjname], action[pkgname])
      end.flatten.uniq
    end

    def calculate_diff(a)
      return if a['type'] != 'submit'
      raise 'We need action_id' unless a['action_id']

      action = BsRequestAction.find(a['action_id'])
      begin
        action.sourcediff(view: nil, withissues: 0)
      rescue BsRequestAction::Errors::DiffError
        nil # can't help
      end
    end

    def headers_for_actions
      ret = {}
      payload['actions'].each_with_index do |a, index|
        suffix = if payload['actions'].length == 1 || index.zero?
                   'X-OBS-Request-Action'
                 else
                   "X-OBS-Request-Action-#{index}"
                 end

        ret["#{suffix}-type"] = a['type']
        if a['targetpackage']
          ret["#{suffix}-target"] = "#{a['targetproject']}/#{a['targetpackage']}"
        elsif a['targetrepository']
          ret["#{suffix}-target"] = "#{a['targetproject']}/#{a['targetrepository']}"
        elsif a['targetproject']
          ret["#{suffix}-target"] = a['targetproject']
        end
        if a['sourcepackage']
          ret["#{suffix}-source"] = "#{a['sourceproject']}/#{a['sourcepackage']}"
        elsif a['sourceproject']
          ret["#{suffix}-source"] = a['sourceproject']
        end
      end
      ret
    end

    def source_from_remote?
      payload['actions'].any? { |action| Project.unscoped.remote_project?(action['sourceproject'], skip_access: true) }
    end

    def payload_without_target_project?
      payload['actions'].any? { |action| !Project.exists_by_name(action['targetproject']) }
    end

    def payload_without_source_project?
      payload['actions'].any? { |action| !Project.exists_by_name(action['sourceproject']) }
    end
  end
end
