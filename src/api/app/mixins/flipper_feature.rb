module FlipperFeature
  def feature_enabled?(feature)
    return if Flipper.enabled?(feature.to_sym, User.possibly_nobody)

    render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
  end
end
