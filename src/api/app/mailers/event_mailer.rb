class EventMailer < ActionMailer::Base

  def event(user, e)
    @host = CONFIG['external_webui_host'] || 'localhost'
    @e = e.payload
    @configuration = ::Configuration.first
    mail(to: user.email,
         subject: e.subject,
         layout: 'layout',
         template_name: e.raw_type.downcase)
  end
end
