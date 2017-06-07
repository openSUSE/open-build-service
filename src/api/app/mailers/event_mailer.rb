class EventMailer < ActionMailer::Base
  helper :comment

  def set_headers
    @host = ::Configuration.obs_url
    @configuration = ::Configuration.first

    headers['Precedence'] = 'bulk'
    headers['X-Mailer'] = 'OBS Notification System'
    headers['X-OBS-URL'] = ActionDispatch::Http::URL.url_for(controller: :main, action: :index, only_path: false, host: @host)
    headers['Auto-Submitted'] = 'auto-generated'
    headers['Return-Path'] = mail_sender
    headers['Sender'] = mail_sender
  end

  def mail_sender
    'OBS Notification <' + ::Configuration.admin_email + '>'
  end

  def email_for_event(subscribers, event)
    begin
      @e = event.expanded_payload
    rescue Project::UnknownObjectError, Package::UnknownObjectError
      return # object got removed already
    end

    subscribers = subscribers.to_a
    return if subscribers.empty?

    set_headers
    headers(event.custom_headers)

    to = subscribers.map(&:display_name).sort
    origin = event.originator ? event.originator.display_name : mail_sender

    mail(to: to,
         subject: event.subject,
         from: origin,
         date: event.created_at,
         template_name: event.template_name)
  end
end
