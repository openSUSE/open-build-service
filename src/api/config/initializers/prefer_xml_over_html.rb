# Custom Rack middleware to prefer XML over HTML whenever the HTTP header HTTP_ACCEPT isn't set in a request.
# Without this, clients like `osc` attempt to fetch HTML and they end up getting 404s as OBS has been defaulting to XML
# since the commit 8145e40a6266f40ce771052fd11e372efc85e116 was introduced many, many years ago. Changing all clients
# is a lot of work, so we stick to this default.
#
# Details on HTTP_ACCEPT:
# https://www.rfc-editor.org/rfc/rfc9110.html#name-accept
class PreferXmlOverHtml
  def initialize(app)
    @app = app
  end

  def call(env)
    env['HTTP_ACCEPT'] ||= 'application/xml'
    @app.call(env)
  end
end

OBSApi::Application.config.middleware.use(PreferXmlOverHtml)
