class EventMailer < ActionMailer::Base
  helper 'webui/markdown'

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

  def event(subscribers, e)
    subscribers = subscribers.to_a
    return if subscribers.empty?

    recipients = subscribers.map(&:display_name).reject(&:blank?)
    return if recipients.empty?

    set_headers
    begin
      locals = { event: e.expanded_payload }
    rescue Project::UnknownObjectError, Package::UnknownObjectError
      # object got removed already
      return
    end

    headers(e.custom_headers)

    template_name = e.template_name
    orig = e.originator

    orig = if orig
             orig.display_name
           else
             mail_sender
           end

    mail(to: recipients.sort,
         subject: e.subject,
         from: orig,
         date: e.created_at) do |format|
      format.html { render template_name, locals: locals } if template_exists?("event_mailer/#{template_name}", formats: [:html])

      format.text { render template_name, locals: locals } if template_exists?("event_mailer/#{template_name}", formats: [:text])
    end
  end
end
