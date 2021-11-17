class CheckUpgradeMailer < ActionMailer::Base
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

  def send

    #FIXME 
    #Get params

    mail(to: user_email,
         subject: subject,
         from: mail_sender,
         date: updated_at) do |format|
      format.html { render template_name, locals: locals } if template_exists?("event_mailer/#{template_name}", formats: [:html])
      format.text { render template_name, locals: locals } if template_exists?("event_mailer/#{template_name}", formats: [:text])
    end
  end
end
