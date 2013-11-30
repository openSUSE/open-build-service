class EventMailer < ActionMailer::Base

  def set_headers
    @host = ::Configuration.first.obs_url
    @configuration = ::Configuration.first

    headers['Precdence'] = 'bulk'
    headers['X-Mailer'] = 'OBS Notification System'

  end

  def event(user, e)
    set_headers
    @e = e.expanded_payload

    headers(e.custom_headers)

    template_name = e.class.name.gsub('Event::', '').underscore
    mail(to: user.email,
         subject: e.subject,
         from: 'hermes@opensuse.org',
         template_name: template_name)
  end

end
