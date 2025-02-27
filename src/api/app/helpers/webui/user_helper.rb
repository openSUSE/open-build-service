module Webui::UserHelper
  def display_applied_filters(filters, user)
    tag.span(class: 'd-block ms-4 mb-3') do
      link_to(user) do
        safe_join(
          [
            tag.i(class: 'fas fa-trash-alt pe-2'),
            "Clear current search #{display_filters(filters.keys).to_sentence}"
          ]
        )
      end
    end
  end

  def display_filters?(filters)
    filters != ['search_text']
  end

  def user_actions(user)
    safe_join(
      [
        link_to(edit_user_path(user.login)) do
          tag.i(nil, class: 'fas fa-edit text-secondary pe-1', title: 'Edit User')
        end,
        mail_to(user.email) do
          tag.i(nil, class: 'fas fa-envelope text-secondary pe-1', title: 'Send Email to User')
        end,
        unless user.state == 'deleted'
          link_to('#', title: 'Delete User', data: { 'bs-toggle': 'modal',
                                                     'bs-target': '#delete-user-modal', 'user-login': user.login, action: user_path(user.login) }) do
            tag.i(nil, class: 'fas fa-times-circle text-danger pe-1')
          end
        end
      ]
    )
  end

  def realname_with_login(user)
    if user.realname.present?
      "#{user.realname} (#{user.login})"
    else
      user.login
    end
  end

  def user_with_realname_and_icon(user, opts = {})
    defaults = { short: false, no_icon: false }
    opts = defaults.merge(opts)

    user = User.find_by_login(user) unless user.is_a?(User)
    return '' unless user

    Rails.cache.fetch([user, 'realname_and_icon', opts]) do
      printed_name = if opts[:short]
                       user.login
                     else
                       realname_with_login(user)
                     end

      if opts[:no_icon]
        link_to(printed_name, user_path(user))
      else
        image_tag_for(user, size: 20) + ' ' + link_to(printed_name, user_path(user))
      end
    end
  end

  def requester_str(creator, requester_user, requester_group)
    # we don't need to show the requester if they are the same as the creator
    return if creator == requester_user

    if requester_user
      "the user #{user_with_realname_and_icon(requester_user, no_icon: true)}".html_safe
    elsif requester_group
      "the group #{requester_group}"
    end
  end

  def activity_date_commits(projects)
    return tag.div(activity_date_commits_project(projects.first), class: 'h6 mt-3') if projects.size == 1

    max_projects = max_activity_items(3, projects)
    concat(tag.div(pluralize(projects.sum(&:last), 'commit'), class: 'h6 mt-3'))
    tag.ul do
      projects[0..(max_projects - 1)].each do |commit_row|
        concat(tag.li(activity_date_commits_project(commit_row), class: 'mt-1'))
      end
      diff = projects.size - max_projects
      concat(tag.li("and in #{pluralize(diff, 'project')} more", class: 'mt-1')) if diff.positive?
    end
  end

  def filter_message(params)
    roles = params.select { |param| param.include?('role') }.keys
    result = "This user is not involved in any #{project_package_message}"
    result += " for the selected #{'role'.pluralize(roles.count)}" if roles.present?
    "#{result}."
  end

  private

  def project_package_message
    arr = []
    arr << 'project' if params['involved_projects']
    arr << 'package' if params['involved_packages']

    arr.blank? ? 'project or package' : arr.join(' or ')
  end

  def display_filters(filters)
    filters.collect do |filter|
      case filter.to_sym
      when :search_text
        'query'
      when /role_.*/
        'roles'
      when /involved_.*/
        filter.to_s.split('_').last
      end
    end.uniq
  end

  def activity_date_commits_project(commit_line)
    project, packages, count = commit_line

    return single_package_commits_line(project, packages.first.first, count) if packages.size == 1

    multiple_packages_commits_line(project, packages, count)
  end

  def multiple_packages_commits_line(project, packages, count)
    max_packages = max_activity_items(3, packages)
    capture do
      concat(pluralize(count, 'commit'))
      concat(' in ')
      concat(link_to(project, project_show_path(project)))
      tag.ul(class: 'mt-1') do
        packages = packages.sort_by { |_, c| -c }
        packages[0..(max_packages - 1)].each do |package, commit_count|
          tag.li do
            concat(pluralize(commit_count, 'commit'))
            concat(' in ')
            concat(link_to(package, package_show_path(project, package)))
          end
          count -= commit_count
        end
      end
      diff = packages.size - max_packages
      tag.li("and #{pluralize(count, 'commit')} in #{pluralize(diff, 'package')} more") if diff.positive?
    end
  end

  def single_package_commits_line(project, single_package, count)
    capture do
      concat(pluralize(count, 'commit'))
      concat(' in ')
      concat(link_to("#{project} / #{single_package}", package_show_path(project, single_package)))
    end
  end

  def max_activity_items(max_items, items_array)
    max_items += 1 if items_array.size == (max_items + 1)
    max_items
  end
end
