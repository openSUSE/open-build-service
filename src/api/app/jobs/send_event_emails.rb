class SendEventEmails
  #include ActionController::Rendering

  def perform
    Event::Base.where(mails_sent: false).order(:created_at).limit(1000).lock(true).each do |event|
      event.mails_sent = true
      begin
        event.save!
      rescue ActiveRecord::StaleObjectError
        # if someone else saved it too, better don't continue - we're not alone
        return false
      end

      next if event.subscriptions.empty?

      subscriptions = event.subscriptions.reject(&:digest_email_enabled?)
      digest_subscriptions = event.subscriptions.select(&:digest_email_enabled?)

      # Send an email to the subscribers with digest_email_enabled == false
      if subscriptions.any?
        EventMailer.email_for_event(subscriptions.map(&:subscriber), event).deliver_now
      end

      # Add to a digest email for the subscribers with digest_email_enabled == true
      digest_subscriptions.each do |subscription|
        add_event_to_digest_subscription(event, subscription)
      end
    end
  end

  private

  def add_event_to_digest_subscription(event, subscription)
    digest_email = DigestEmail.find_or_create_by(event_subscription: subscription)
    event_email = EventMailer.email_for_event([subscription.subscriber], event)

    # Process html part of email
    if digest_email.body_html.blank?
      digest_email.body_html = event_email.html_part.body.raw_source
    else
      digest_email.body_html += divider_html
      digest_email.body_html += event_email.html_part.body.raw_source
    end

    # Process text part of email
    if digest_email.body_text.blank?
      digest_email.body_text = event_email.text_part.body.raw_source
    else
      digest_email.body_text += divider_text
      digest_email.body_text += event_email.text_part.body.raw_source
    end

    digest_email.save!
  end

  def divider_html
    ActionController::Base.new.render_to_string 'event_mailer/divider', layout: false, formats: [:html]
  end

  def divider_text
    ActionController::Base.new.render_to_string 'event_mailer/divider', layout: false, formats: [:text]
  end
end
