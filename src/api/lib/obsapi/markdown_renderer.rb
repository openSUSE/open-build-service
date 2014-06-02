module OBSApi
  class MarkdownRenderer < Redcarpet::Render::HTML
    include Rails.application.routes.url_helpers

    def self.default_url_options
      @uri ||= URI.parse ::Configuration.first.obs_url
      { host: @uri.host, port: @uri.port }
    end

    def preprocess(fulldoc)
      # OBS requests
      out = fulldoc.gsub(/(sr|req)#(\d+)/) {|s| "<a href=\"#{request_show_url(id: $2)}\">#{s}</a>" }
      # issues
      IssueTracker.all.each do |t|
        out = t.get_html(out)
      end
      # users
      out.gsub!(/([^\w])@(\w+)([^\w]|$)/) {|s| "#{$1}<a href=\"#{user_show_url($2)}\">@#{$2}</a>#{$3}" }
      out
    end
  end
end
