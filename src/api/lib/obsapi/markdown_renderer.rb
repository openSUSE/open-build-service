module OBSApi
  class MarkdownRenderer < Redcarpet::Render::HTML
    include Rails.application.routes.url_helpers

    def self.default_url_options
      { host: ::Configuration.first.obs_url }
    end

    def preprocess(fulldoc)
      # OBS requests
      out = fulldoc.gsub(/(sr|req|request)#(\d+)/i) {|s| "<a href=\"#{request_show_url(id: $2)}\">#{s}</a>" }
      # issues
      IssueTracker.all.each do |t|
        out = t.get_html(out)
      end
      # users
      out.gsub!(/([^\w]|^)@([-\w]+)([^\w]|$)/) do
        # We need to save $1,$2 and $3 since we are calling gsub again inside the block
        s1, s2, s3 = $1, $2, $3
        "#{s1}<a href=\"#{user_show_url(s2)}\">@#{s2.gsub('_','\_')}</a>#{s3}"
      end
      out
    end
  end
end
