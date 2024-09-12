class AdminMailer < ActionMailer::Base
  default Precedence: 'bulk',
          'X-Mailer': 'OBS Administrator Notification',
          'X-OBS-URL': ActionDispatch::Http::URL.url_for(controller: :main, action: :index, only_path: false, host: @host),
          'Auto-Submitted': 'auto-generated',
          'Return-Path': mail_sender,
          Sender: mail_sender

  def error(message)
    warning(message, 'ERROR')
  end

  def warning(message, level = 'Warning')
    set_host
    return unless @host

    # FIXME/to be implemented:
    # we may want to use the event system to allow to manage subscribers.
    # but only when we detect that there is currently no problem with the event or delayed job system
    #
    # we should classify the problems and record them. This will allow to show the
    # issues to the admins in webui and they can work on them
    # the problems should get updated or removed when we detect changes.

    mail(to: admins,
         subject: "OBS Administrator #{level}",
         from: ::Configuration.admin_email,
         date: Time.now,
         body: message)
  end

  private

  def set_host
    @host = ::Configuration.obs_url
  end

  def mail_sender
    "OBS Admin Notification <#{::Configuration.admin_email}>"
  end

  def admins
    # find all admins. No opt-out atm
    r = Role.find_by_title('Admin')
    RolesUser.where(role: r).map { |ru| ru.user.email }
  end
end
