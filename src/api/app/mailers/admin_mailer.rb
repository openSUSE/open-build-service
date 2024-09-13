class AdminMailer < ApplicationMailer
  before_action :set_admin_headers

  default 'X-Mailer': 'OBS Administrator Notification'

  def error(message)
    warning(message, 'ERROR')
  end

  def warning(message, level = 'Warning')
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

  def set_admin_headers
    headers 'Return-Path': mail_sender,
            Sender: mail_sender
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
