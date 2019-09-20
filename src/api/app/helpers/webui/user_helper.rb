module Webui::UserHelper
  def user_actions(user)
    safe_join(
      [
        link_to(user_edit_path(user.login)) do
          content_tag(:i, nil, class: 'fas fa-edit text-secondary pr-1', title: 'Edit User')
        end,
        mail_to(user.email) do
          content_tag(:i, nil, class: 'fas fa-envelope text-secondary pr-1', title: 'Send Email to User')
        end,
        link_to(user_path(user.login), method: :delete, data: { confirm: 'Are you sure?' }) do
          content_tag(:i, nil, class: 'fas fa-times-circle text-danger pr-1', title: 'Delete User')
        end
      ]
    )
  end

  # This method is migrated to Webui2 (and refactored) with the name: image_tag_for
  # @param [User] user object
  def user_image_tag(user, opt = {})
    alt = opt[:alt] || user.try(:realname)
    alt = user.try(:login) if alt.empty?
    size = opt[:size] || 20
    if user.try(:email) && ::Configuration.gravatar
      url = "https://www.gravatar.com/avatar/#{Digest::MD5.hexdigest(user.email.downcase)}?s=#{size}&d=robohash"
    else
      url = 'default_face.png'
    end
    image_tag(url, width: size, height: size, alt: alt, class: opt[:css_class])
  end

  def user_with_realname_and_icon(user, opts = {})
    defaults = { short: false, no_icon: false }
    opts = defaults.merge(opts)

    user = User.find_by_login(user) unless user.is_a?(User)
    return '' unless user

    Rails.cache.fetch([user, 'realname_and_icon', opts, ::Configuration.first]) do
      realname = user.realname

      if opts[:short] || realname.empty?
        printed_name = user.login
      else
        printed_name = "#{realname} (#{user.login})"
      end

      if opts[:no_icon]
        link_to(printed_name, user_path(user))
      else
        link_to(user_image_tag(user, css_class: opts[:css_class]), user_path(user)) +
          ' ' + link_to(printed_name, user_path(user))
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
