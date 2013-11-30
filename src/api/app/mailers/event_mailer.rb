class EventMailer < ActionMailer::Base

  def event(user, e)
    @host = ::Configuration.first.obs_url
    @e = e.payload
    @configuration = ::Configuration.first

    headers(e.custom_headers)

    headers['Precdence'] = 'bulk'
    headers['X-Mailer'] = 'OBS Notification System'

    mail(to: user.email,
         subject: e.subject,
         from: 'hermes@opensuse.org',
         template_name: e.raw_type.downcase)
  end
end
