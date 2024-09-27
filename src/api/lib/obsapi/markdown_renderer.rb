require 'uri'
require 'cgi'

module OBSApi
  class MarkdownRenderer < Redcarpet::Render::Safe
    include Rails.application.routes.url_helpers

    def self.default_url_options
      { host: ::Configuration.first.obs_url }
    end

    def preprocess(fulldoc)
      # request#12345 links
      fulldoc.gsub!(/(sr|req|request)#(\d+)/i) { |s| "[#{s}](#{request_show_url(number: Regexp.last_match(2))})" }
      # @user links
      fulldoc.gsub!(/([^\w]|^)@(\b[-.\+\w]+\b)(?:\b|$)/) { "#{Regexp.last_match(1)}[@#{escape_markdown(Regexp.last_match(2))}](#{user_url(Regexp.last_match(2))})" }
      # bnc#12345 links
      IssueTracker.find_each do |t|
        fulldoc = t.get_markdown(fulldoc)
      end
      fulldoc
    end

    # unfortunately we can't call super (into C) - see vmg/redcarpet#51
    def link(link, title, content)
      # A return value of nil will not output any data
      # the contents of the span will be copied verbatim
      return nil if link.blank?

      title = " title='#{title}'" if title.present?
      begin
        link = URI.join(::Configuration.obs_url, link)
      rescue URI::InvalidURIError
        # Ignore this exception on purpose
      end
      "<a href='#{link}'#{title}>#{CGI.escape_html(content)}</a>"
    end

    def block_code(code, language)
      language ||= :plaintext
      CodeRay.scan(code, language).div(css: :class)
    rescue ArgumentError
      CodeRay.scan(code, :plaintext).div(css: :class) unless language == :plaintext
    end

    private

    def escape_markdown(text)
      text.gsub(/([_*`~])/, '\\\\\1')
    end
  end
end
