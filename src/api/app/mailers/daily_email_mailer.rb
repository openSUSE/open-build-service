class DailyEmailMailer < ActionMailer::Base
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

  def notifications(subscriber, notifications)
    subscribers = subscribers.to_a

    set_headers

    mail(to: subscriber.display_name,
         subject: 'Daily Notifications Update',
         from: ::Configuration.admin_email,
         date: Time.now) do |format|

      render_args = ['daily_email_mailer/notifications', { layout: false, locals: { notifications: notifications } }]

      format.text { render *render_args }
      format.html { render *render_args }
    end
  end
end
