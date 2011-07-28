class IssueTracker < ActiveXML::Base

  class ListError < Exception; end
  class ModifyError < Exception; end

  default_find_parameter :id

  class << self
    def make_stub(opt)
      acronyms = ''
      if opts[:acronyms]
        opts[:acronyms].each do |acronym|
          acronyms += "<acronym><name>#{acronym}</name></acronym>"
        end
        acronyms = "<acronyms>#{acronyms}</acronyms>"
      end

      reply = <<-EOF
        <issue-tracker>
          <name>#{opt[:name]}</name>
          <url>#{opt[:url]}</url>
          <show-url>#{opt[:show_url]}</show-url>
          #{acronyms}
        </issue-tracker>
      EOF
      return reply
    end

    def acronyms_with_urls_hash
      return Rails.cache.fetch('issue_trackers_all_acronyms', :expires_in => 5.minutes) do
        acronyms_with_urls_hash = {}
        find_cached(:all).each do |tracker| # Iterate over all issue trackers
          tracker.acronyms.each do |acronym| # Iterate over all acronyms for that specific issue tracker
            acronyms_with_urls_hash[acronym.value('name')] = { :show_url => tracker.find_first('show-url').to_s }
          end
        end
        acronyms_with_urls_hash
      end
    end
  end
end
