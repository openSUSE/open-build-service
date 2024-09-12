class EventMailer < ApplicationMailer
  helper 'webui/markdown'
  helper 'webui/reportables'

  before_action :set_configuration_title
  before_action :set_recipients
  before_action :set_event
  before_action :set_event_headers

  default 'X-Mailer': 'OBS Notification System',
          Sender: email_address_with_name(::Configuration.admin_email, 'OBS Notification')

  def notification_email
    return if @recipients.blank? || @event.blank?

    mail(to: @recipients,
         from: email_address_with_name(::Configuration.admin_email, sender_realname),
         subject: @event.subject,
         date: @event.created_at) do |format|
      format.html { render @event.template_name, locals: { event: @event.expanded_payload } } if template_exists?("event_mailer/#{@event.template_name}", formats: [:html])

      format.text { render @event.template_name, locals: { event: @event.expanded_payload } } if template_exists?("event_mailer/#{@event.template_name}", formats: [:text])
    end
  end

  private

  def set_configuration_title
    @configuration_title = ::Configuration.title
  end

  def set_recipients
    return unless params[:subscribers]

    @recipients = params[:subscribers].map(&:display_name).compact_blank.sort
  end

  def set_event
    @event = params[:event]
  end

  def set_event_headers
    return unless @event

    headers 'Message-ID': message_id,
            'X-OBS-event-type': @event.template_name

    headers(@event.custom_headers)
  end

  def sender_realname
    return unless @event
    return 'OBS Notification' unless @event.originator

    "#{@event.originator.realname} (#{@event.originator.login})"
  end

  def message_id
    domain = URI.parse(@host).host.downcase
    # FIXME: Stop mocking with this in code.
    #        Migrate the unit tests to RSpec and compare headers from the message object...
    content = "<notrandom@#{domain}>" if Rails.env.test?
    content ||= "<#{Mail.random_tag}@#{domain}>"

    content
  end
end
