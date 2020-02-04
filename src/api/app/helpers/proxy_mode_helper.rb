module ProxyModeHelper
  # last visited url in our app, unless it's the login/sign up path
  def return_to_location
    return root_path unless request.env['HTTP_REFERER'].to_s.start_with?(base_url)
    return root_path if request.env['HTTP_REFERER'].to_s.end_with?(new_session_path, new_user_path)
    request.env['HTTP_REFERER'].delete_prefix(base_url)
  end

  private

  def base_url
    url = "#{request.protocol}#{request.host}"
    url += ":#{request.port}" if request.port.present?
    url
  end
end
