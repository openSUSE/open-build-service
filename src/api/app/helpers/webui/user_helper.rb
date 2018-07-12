module Webui::UserHelper
  def user_image_tag(user, opt = {})
    alt = opt[:alt] || user.realname
    alt = user.login if alt.empty?
    size = opt[:size] || 20
    if ::Configuration.gravatar
      hash = Digest::MD5.hexdigest(user.email.downcase)
      url = "http://www.gravatar.com/avatar/#{hash}?s=#{size}&d=wavatar"
    else
      url = 'default_face.png'
    end
    image_tag(url, width: size, height: size, alt: alt, class: opt[:css_class])
  end

  # @param [String] user login of the user
  # @param [String] role title of the login
  # @param [Hash]   options boolean flags :short, :no_icon
  def user_and_role(user, role = nil, options = {})
    opt = { short: false, no_icon: false }.merge(options)
    real_name = User.not_deleted.find_by(login: user).try(:realname)

    if opt[:no_icon]
      icon = ''
    else
      # user_icon returns an ActiveSupport::SafeBuffer and not a String
      icon = user_image_tag(user)
    end

    if real_name.empty? || opt[:short]
      printed_name = user
    else
      printed_name = "#{real_name} (#{user})"
    end

    printed_name << " as #{role}" if role

    # It's necessary to concat icon and $variable and don't use string interpolation!
    # Otherwise we get a new string and not an ActiveSupport::SafeBuffer
    if User.current.is_nobody?
      icon + printed_name
    else
      icon + link_to(printed_name, user_show_path(user))
    end
  end

  def user_with_realname_and_icon(user, opts = {})
    defaults = { short: false, no_icon: false }
    opts = defaults.merge(opts)

    user = User.find_by_login(user) unless user.is_a? User
    return '' unless user

    Rails.cache.fetch([user, 'realname_and_icon', opts, ::Configuration.first]) do
      realname = user.realname

      if opts[:short] || realname.empty?
        printed_name = user.login
      else
        printed_name = "#{realname} (#{user.login})"
      end

      user_icon(user) + ' ' + link_to(printed_name, user_show_path(user))
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
end
