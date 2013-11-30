class EventMailer < ActionMailer::Base

  def set_headers
    @host = ::Configuration.first.obs_url
    @configuration = ::Configuration.first

    headers['Precdence'] = 'bulk'
    headers['X-Mailer'] = 'OBS Notification System'

  end

  def event(user, e)
    set_headers
    @e = e.payload

    headers(e.custom_headers)

    template_name = e.class.name.gsub('Event::', '').underscore
    mail(to: user.email,
         subject: e.subject,
         from: 'hermes@opensuse.org',
         template_name: template_name)
  end

  def review_wanted(opts, users)
    set_headers

    raise "We need an id" unless opts[:id]

    mid = Event::Request.message_id(opts[:id])
    headers('In-Reply-To' => mid, 'References' => mid)

    @opts = opts
    users.each do |u|
      mail(to: u.email,
           subject: "Request #{opts[:id]}: Review wanted",
           from: 'hermes@opensuse.org',
           template_name: 'review_wanted')
    end
  end
end
