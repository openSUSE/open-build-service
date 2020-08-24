module Webui::UserHelper
  def user_actions(user)
    safe_join(
      [
        link_to(edit_user_path(user.login)) do
          tag.i(nil, class: 'fas fa-edit text-secondary pr-1', title: 'Edit User')
        end,
        mail_to(user.email) do
          tag.i(nil, class: 'fas fa-envelope text-secondary pr-1', title: 'Send Email to User')
        end,
        link_to(user_path(user.login), method: :delete, data: { confirm: 'Are you sure?' }) do
          tag.i(nil, class: 'fas fa-times-circle text-danger pr-1', title: 'Delete User')
        end
      ]
    )
  end

  def user_with_realname_and_icon(user, opts = {})
    defaults = { short: false, no_icon: false }
    opts = defaults.merge(opts)

    user = User.find_by_login(user) unless user.is_a?(User)
    return '' unless user

    Rails.cache.fetch([user, 'realname_and_icon', opts, ::Configuration.first]) do
      realname = user.realname

      printed_name = if opts[:short] || realname.empty?
                       user.login
                     else
                       "#{realname} (#{user.login})"
                     end

      if opts[:no_icon]
        link_to(printed_name, user_path(user))
      else
        image_tag_for(user, size: 20) + ' ' + link_to(printed_name, user_path(user))
      end
    end
  end

  def requester_str(creator, requester_user, requester_group)
    # we don't need to show the requester if he is the same as the creator
    return if creator == requester_user

    if requester_user
      "the user #{user_with_realname_and_icon(requester_user, no_icon: true)}".html_safe
    elsif requester_group
      "the group #{requester_group}"
    end
  end

  def user_is_configurable(configuration, user)
    configuration.ldap_enabled? && !user.ignore_auth_services?
  end
end
