class AdminMailer < ActionMailer::Base
  # avoiding the event mechanism for this, since it might be the actual problem

  def set_headers
    @host = ::Configuration.obs_url
    @configuration = ::Configuration.first

    headers['Precedence'] = 'bulk'
    headers['X-Mailer'] = 'OBS Administrator Notification'
    headers['X-OBS-URL'] = ActionDispatch::Http::URL.url_for(controller: :main, action: :index, only_path: false, host: @host)
    headers['Auto-Submitted'] = 'auto-generated'
    headers['Return-Path'] = mail_sender
    headers['Sender'] = mail_sender
  end

  def mail_sender
    'OBS Admin Notification <' + ::Configuration.admin_email + '>'
  end

  def error(message)
    warning(message, "ERROR")
  end

  def warning(message, level = "Warning")
    set_headers

    # FIXME/to be implemented:
    # we may want to use the event system to allow to manage subscribers.
    # but only when we detect that there is currently no problem with the event or delayed job system
    #
    # we should classify the problems and record them. This will allow to show the
    # issues to the admins in webui and they can work on them
    # the problems should get updated or removed when we detect changes.

    # find all admins. No opt-out atm
    r = Role.find_by_title("Admin")
    admins = RolesUser.where(role: r).map { |ru| ru.user.email }

    mail(to: admins,
         subject: "OBS Administrator #{level}",
         from: ::Configuration.admin_email,
         date: Time.now,
         body: message)
  end
end
