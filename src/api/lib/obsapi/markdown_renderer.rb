require 'uri'
require 'cgi'

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
      fulldoc.gsub!(/([^\w]|^)@(\b[-\w]+\b)(?:\b|$)/) \
                   { "#{Regexp.last_match(1)}[@#{Regexp.last_match(2)}](#{user_url(Regexp.last_match(2))})" }
      # bnc#12345 links
      IssueTracker.all.each do |t|
        fulldoc = t.get_markdown(fulldoc)
      end
      fulldoc
    end

    def block_html(raw_html)
      # sanitize the HTML we get
      Sanitize.fragment(raw_html, Sanitize::Config.merge(Sanitize::Config::RESTRICTED,
                                                         elements: Sanitize::Config::RESTRICTED[:elements] + ['pre'],
                                                         remove_contents: true))
    end

    # unfortunately we can't call super (into C) - see vmg/redcarpet#51
    def link(link, title, content)
      title = " title='#{title}'" if title.present?
      begin
        link = URI.join(::Configuration.obs_url, link)
      rescue URI::InvalidURIError
      end
      "<a href='#{link}'#{title}>#{CGI.escape_html(content)}</a>"
    end

    def block_code(code, language)
      language ||= :plaintext
      CodeRay.scan(code, language).div(css: :class)
    end
  end
end
