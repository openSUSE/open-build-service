class EventMailer < ActionMailer::Base
  helper 'webui/markdown'
  DefaultSender = Struct.new('DefaultSender', :email, :realname)

  before_action :set_configuration
  before_action :set_recipients
  before_action :set_default_headers
  before_action :set_event
  before_action :set_event_headers
  before_action :set_sender

  def notification_email
    return if @recipients.blank? || @event.blank?

    template_name = @event.template_name
    mail(to: @recipients,
         from: email_address_with_name(@sender.email, @sender.realname),
         subject: @event.subject,
         date: @event.created_at) do |format|
      format.html { render template_name, locals: { event: @event.expanded_payload } } if template_exists?("event_mailer/#{template_name}", formats: [:html])

      format.text { render template_name, locals: { event: @event.expanded_payload } } if template_exists?("event_mailer/#{template_name}", formats: [:text])
    end
  end

  private

  def set_configuration
    @configuration = ::Configuration.first

    # FIXME: This if for the view. Use action_mailer.default_url_options instead
    # https://guides.rubyonrails.org/action_mailer_basics.html#generating-urls-in-action-mailer-views
    @host = @configuration.obs_url
  end

  def set_recipients
    return unless params[:subscribers]

    @recipients = params[:subscribers].map(&:display_name).compact_blank.sort
  end

  def set_default_headers
    headers['Precedence'] = 'bulk'
    headers['X-Mailer'] = 'OBS Notification System'
    headers['X-OBS-URL'] = ActionDispatch::Http::URL.url_for(controller: :main, action: :index, only_path: false, host: @configuration.obs_url)
    headers['Auto-Submitted'] = 'auto-generated'
    headers['Return-Path'] = email_address_with_name(@configuration.admin_email, 'OBS Notification')
    headers['Sender'] = email_address_with_name(@configuration.admin_email, 'OBS Notification')
    headers['Message-ID'] = message_id
  end

  def set_event
    @event = params[:event]
  end

  def set_event_headers
    return unless @event

    headers['X-OBS-event-type'] = @event.template_name
    headers(@event.custom_headers)
  end

  def set_sender
    return unless @event

    @sender = @event.originator
    @sender ||= DefaultSender.new(@configuration.admin_email, 'OBS Notification') # rubocop:disable Naming/MemoizedInstanceVariableName
  end

  def message_id
    domain = URI.parse(@configuration.obs_url).host.downcase
    # FIXME: Stop mocking with this in code.
    #        Migrate the unit tests to RSpec and compare headers from the message object...
    content = "<notrandom@#{domain}>" if Rails.env.test?
    content ||= "<#{Mail.random_tag}@#{domain}>"

    content
  end
end
