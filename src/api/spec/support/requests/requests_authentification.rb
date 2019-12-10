module RequestsAuthentication
  def login(user)
    @current_user = user
  end

  def logout
    @current_user = nil
  end

  # rubocop:disable Rails/HttpPositionalArguments
  def api_delete(url, opts = {})
    delete url, wrap_opts(opts)
  end

  def api_get(url, opts = {})
    get url, wrap_opts(opts)
  end

  def api_post(url, opts = {})
    post url, wrap_opts(opts)
  end

  def api_put(url, opts = {})
    put url, wrap_opts(opts)
  end
  # rubocop:enable Rails/HttpPositionalArguments

  def wrap_opts(opts)
    opts[:headers] ||= {}
    opts[:headers]['HTTP_ACCEPT'] = 'application/xml'
    if @current_user
      opts[:headers]['HTTP_AUTHORIZATION'] = 'Basic ' +
                                             Base64.encode64("#{@current_user.login}:#{@current_user.password}")
    end
    opts
  end
end

RSpec.configure do |c|
  c.include RequestsAuthentication, type: :request
end
