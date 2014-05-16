
module OBSApi
  class MarkdownRenderer < Redcarpet::Render::HTML
    include Rails.application.routes.url_helpers

    def preprocess(fulldoc)
      # OBS requests
      out = fulldoc.gsub(/(sr|req)#(\d+)/) {|s| "<a href=\"#{request_show_path(id: $2)}\">#{s}</a>" }
      # issues
      IssueTracker.all.each do |tracker|
        exp = Regexp.new(tracker.regex)
        out.gsub!(exp) {|s| "<a href=\"#{tracker.show_url_for($1)}\">#{s}</a>" }
      end
      out
    end
  end
end
