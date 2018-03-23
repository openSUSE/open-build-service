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
    return if subscribers.empty?

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
    tos = subscribers.map(&:display_name)

    if orig
      orig = orig.display_name
    else
      orig = mail_sender
    end

    begin
      mail(to: tos.sort,
           subject: e.subject,
           from: orig,
           date: e.created_at) do |format|

        if template_exists?("event_mailer/#{template_name}", formats: [:html])
          format.html { render template_name, locals: locals }
        end

        if template_exists?("event_mailer/#{template_name}", formats: [:text])
          format.text { render template_name, locals: locals }
        end
      end
    rescue ArgumentError
      Rails.logger.error "ArgumentError (catched): template: #{template_name}, locals: #{locals.inspect}, tos: #{tos.inspect}, orig: #{orig}"
      raise
    end
  end
end
