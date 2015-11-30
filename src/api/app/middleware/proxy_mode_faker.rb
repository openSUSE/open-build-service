class ProxyModeFaker
  def initialize(app)
    @app = app
  end

  def call(env)
    env['HTTP_X_USERNAME'] = 'pico'
    env['HTTP_X_EMAIL']  = 'pico@werder.de'
    env['HTTP_X_FIRSTNAME'] =  'Arnold Pico'
    env['HTTP_X_LASTNAME'] = 'Schütz'
    @app.call env
  end
end
