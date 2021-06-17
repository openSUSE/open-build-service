module FlipperFeature
  def feature_enabled?(feature)
    return if Flipper.enabled?(feature.to_sym, User.possibly_nobody)

    render file: Rails.root.join('public/404.html'), status: :not_found, layout: false
  end
end
