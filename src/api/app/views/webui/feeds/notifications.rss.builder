xml.rss version: '2.0' do
  xml.channel do
    xml.title "#{@user.realname} (#{@user.login}) notifications"
    xml.description "Event notifications from #{@configuration['title']}"
    xml.link url_for only_path: false, controller: 'main', action: 'index'
    xml.language 'en'
    xml.pubDate Time.now
    xml.generator @configuration['title']

    @notifications.each do |notification|
      xml.item do
        if notification.notifiable && notification.event_type != 'Event::ReviewWanted'
          xml.title notification.title
          xml.description render(
            template: "notifications/#{notification.template_name}",
            layout: false,
            formats: :text,
            locals: { notification: notification }
          )
        else
          xml.title notification.event.subject
          xml.description render(
            template: "event_mailer/#{notification.event.template_name}",
            layout: false,
            formats: :text,
            locals: { event: notification.event.expanded_payload }
          )
        end
        xml.category "#{notification.event_type}/#{notification.subscription_receiver_role}"
        xml.pubDate notification.created_at
        xml.author @configuration['title']
      end
    end
  end
end
