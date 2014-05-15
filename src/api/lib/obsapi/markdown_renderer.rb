
module OBSApi
  class MarkdownRenderer < Redcarpet::Render::HTML
    include Rails.application.routes.url_helpers

    def preprocess(fulldoc)
      out = fulldoc.gsub(/(sr|req)#(\d+)/) {|s| "<a href=\"#{request_show_path(id: $2)}\">#{s}</a>" }
      IssueTracker.where(kind: 'bugzilla').each do |tracker|
        exp = Regexp.new("#{tracker.name}#(\\d+)")
        url = tracker.url.chomp("/")
        url.gsub!(/apibugzilla/, 'bugzilla') # Specific hack for build.opensuse.org
        out.gsub!(exp) {|s| "<a href=\"#{url}/show_bug.cgi?id=#{$1}\">#{s}</a>" }
      end
      IssueTracker.where(kind: 'fate').each do |tracker|
        exp = Regexp.new("#{tracker.name}#(\\d+)")
        url = tracker.url.chomp("/")
        out.gsub!(exp) {|s| "<a href=\"#{url}/#{$1}\">#{s}</a>" }
      end
      out
    end
  end
end
