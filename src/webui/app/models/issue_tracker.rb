class IssueTracker < ActiveXML::Base

  class ListError < Exception; end
  class ModifyError < Exception; end

  default_find_parameter :id

  class << self
    def make_stub(opt)
      reply = <<-EOF
        <issue-tracker>
          <name>#{opt[:name]}</name>
          <description>#{opt[:description]}</description>
          <kind>#{opt[:kind]}</kind>
          <regex>#{opt[:regex]}</regex>
          <url>#{opt[:url]}</url>
          <show-url>#{opt[:show_url]}</show-url>
        </issue-tracker>
      EOF
      return reply
    end

    def issues_in(text)
      path = "/issue_trackers/issues_in?format=json&text=#{URI.escape(text)}"
      response = ActiveXML::Config::transport_for(:issuetracker).direct_http(URI(path))
      return ActiveSupport::JSON.decode(response)
    end
  end
end
