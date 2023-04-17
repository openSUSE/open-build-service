class AvatarAndLinkComponent < ApplicationComponent
  attr_reader :avatar_object, :size, :shape, :avatar_css, :long_link_text

  def initialize(avatar_object:, size: 23, shape: nil, avatar_css: '', long_link_text: false)
    super

    @avatar_object = avatar_object
    @size = size
    @shape = shape
    @avatar_css = avatar_css
    @long_link_text = long_link_text
  end

  private

  def link_text
    return avatar_object.title if avatar_object.is_a?(Group)

    return "#{avatar_object.realname} (#{avatar_object.login})" if long_link_text && avatar_object.realname.present?

    avatar_object.login
  end

  def url
    avatar_object
  end
end
