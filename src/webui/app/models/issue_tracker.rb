class IssueTracker < ActiveXML::Node

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
          <label>#{opt[:label]}</label>
          <regex>#{opt[:regex]}</regex>
          <url>#{opt[:url]}</url>
          <show-url>#{opt[:show_url]}</show-url>
        </issue-tracker>
      EOF
      return reply
    end

  end
end
