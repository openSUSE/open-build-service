module OBSApi
  class MarkdownRenderer < Redcarpet::Render::HTML
    include Rails.application.routes.url_helpers

    def self.default_url_options
      { host: ::Configuration.first.obs_url }
    end

    def preprocess(fulldoc)
      # request#12345 links
      fulldoc.gsub!(/(sr|req|request)#(\d+)/i) { |s| "[#{s}](#{request_show_url(number: Regexp.last_match(2))})" }
      # @user links
      fulldoc.gsub!(/([^\w]|^)@([-\w]+)([^\w]|$)/) \
                   { "#{Regexp.last_match(1)}[@#{Regexp.last_match(2)}](#{user_show_url(Regexp.last_match(2))})#{Regexp.last_match(3)}" }
      # bnc#12345 links
      IssueTracker.all.each do |t|
        fulldoc = t.get_markdown(fulldoc)
      end
      # sanitize the HTML we get
      Sanitize.fragment(fulldoc, Sanitize::Config.merge(Sanitize::Config::RESTRICTED,
                                                        elements: Sanitize::Config::RESTRICTED[:elements] + ['pre'],
                                                        remove_contents: true
                                                       ))
    end
  end
end
