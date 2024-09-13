class ConsistencyMailer < AdminMailer
  def errors(errors)
    set_headers
    return unless @host

    @errors = errors
    mail(to: admins,
         subject: 'OBS Administrator errors',
         from: ::Configuration.admin_email,
         date: Time.now.utc)
  end
end
