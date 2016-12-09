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

  def event(subscribers, e)
    subscribers = subscribers.to_a

    set_headers
    begin
      @e = e.expanded_payload
    rescue Project::UnknownObjectError, Package::UnknownObjectError
      # object got removed already
      return
    end

    headers(e.custom_headers)

    template_name = e.template_name
    orig = e.originator

    # no need to tell user about this own actions
    # TODO: make configurable?
    subscribers.delete(orig)
    return if subscribers.empty?

    tos = subscribers.map { |u| u.display_name }

    orig = if orig
      orig.display_name
    else
      mail_sender
    end

    mail(to: tos.sort,
         subject: e.subject,
         from: orig,
         date: e.created_at,
         template_name: template_name)
  end
end
