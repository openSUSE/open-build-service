class EventMailer < ActionMailer::Base

  def set_headers
    @host = ::Configuration.first.obs_url
    @configuration = ::Configuration.first

    headers['Precedence'] = 'bulk'
    headers['X-Mailer'] = 'OBS Notification System'
    headers['X-OBS-URL'] = ActionDispatch::Http::URL.url_for(controller: :main, action: :index, only_path: false, host: @host)
    headers['Auto-Submitted'] = 'auto-generated'
    headers['Return-Path'] = mail_sender
    headers['Sender'] = mail_sender
  end

  def mail_sender
    'OBS Notification <' + ::Configuration.first.admin_email + '>'
  end

  def format_email(user)
    address = Mail::Address.new user.email
    address.display_name = user.realname
    address.format
  end

  def event(users, e)
    users = users.to_a

    set_headers
    @e = e.expanded_payload

    headers(e.custom_headers)

    template_name = e.template_name
    orig = e.originator

    # no need to tell user about this own actions
    # TODO: make configurable?
    users.delete(orig)
    return if users.empty?

    tos = users.map { |u| format_email(u) }

    if orig
      orig = format_email(orig)
    else
      orig = mail_sender
    end

    mail(to: tos,
         subject: e.subject,
         from: orig,
         template_name: template_name)
  end

end
