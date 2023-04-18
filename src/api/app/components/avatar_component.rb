# View Component to display a group or user avatar. Circle shape is optional. Size and CSS classes can be customized.
class AvatarComponent < ApplicationComponent
  attr_reader :name, :email, :size, :shape, :custom_css

  def initialize(name:, email:, size: 23, shape: nil, custom_css: '')
    super

    @name = name
    @email = email
    @size = size
    @shape = shape
    @custom_css = custom_css
  end

  private

  def title
    name
  end

  def alt
    "#{name}'s avatar"
  end

  def gravatar_icon
    if ::Configuration.gravatar && email
      "https://www.gravatar.com/avatar/#{Digest::MD5.hexdigest(email.downcase)}?s=#{size}&d=robohash"
    else
      'default_face.png'
    end
  end

  def css
    css_classes = ['img-fluid']
    css_classes << 'rounded-circle bg-light border border-gray-400' if shape == :circle
    css_classes << custom_css
    css_classes.join(' ')
  end
end
