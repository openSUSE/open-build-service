class CheckUpgradeMailer < ActionMailer::Base
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

  def send_email
    set_headers
    @packageCheckUpgrade = params[:packageCheckUpgrade]

    package_name = Package.find_by(id: @packageCheckUpgrade.package_id).name
    subject = "Check upgrade for #{package_name} package"

    mail(to: @packageCheckUpgrade.user_email, subject: subject, from: mail_sender,
         date: @packageCheckUpgrade.updated_at)
  end
end
