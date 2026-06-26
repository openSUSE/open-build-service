module MetaTagHelper
  def meta_title
    content_for(:meta_title) || home_title
  end

  def meta_image
    content_for(:meta_image) || image_url('obs-logo_meta.png')
  end

  def meta_description
    content_for(:meta_description)
  end

  def gravatar_url(email)
    if ::Configuration.gravatar && email
      "https://www.gravatar.com/avatar/#{Digest::MD5.hexdigest(email.downcase)}.jpg?d=#{CGI.escape(image_url('obs-logo_meta.png'))}"
    else
      image_url('obs-logo_meta.png')
    end
  end
end
