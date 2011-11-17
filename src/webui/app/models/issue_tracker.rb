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
      path = "/issue_trackers/issues_in?text=#{URI.escape(text)}"
      response =  ActiveXML::Config::transport_for(:issuetracker).direct_http(URI(path))
      return ActiveSupport::JSON.decode(response)
    end

    def show_url_for(issue)
      path = "/issue_trackers/show_url_for?issue=#{URI.escape(issue)}"
      return ActiveXML::Config::transport_for(:issuetracker).direct_http(URI(path))
    end

    def regex_show_url_hash
      return Rails.cache.fetch('issue_trackers_all_regex', :expires_in => 5.minutes) do
        regex_hash = {}
        find_cached(:all).each do |it| # Iterate over all issue trackers
          regex_hash[it.value('regex')] = it.value('show-url') if it.value('regex')
        end
        regex_hash
      end
    end
  end
end
