# internal CVE parser class
class IssueTracker::CVEParser < Nokogiri::XML::SAX::Document
  @my_tracker = nil
  @my_issue = nil
  @my_summary = ''
  @is_desc = false

  def tracker=(tracker)
    @my_tracker = tracker
  end

  def start_element(name, attrs = [])
    if name == 'item'
      cve = cve(attrs)
      @my_issue = Issue.find_or_create_by_name_and_tracker(cve.gsub(/^CVE-/, ''), @my_tracker.name)
      reset_values
    end
    @isc_issue = my_issue_and_desc_name(name) || false
  end

  def characters(content)
    return unless @is_desc

    @my_summary += content.chomp
  end

  def end_element(name)
    return unless name == 'item'

    if @my_summary.present?
      @my_issue.summary = @my_summary[0..254]
      @my_issue.save
    end
    @my_issue = nil
  end

  def cve(attrs)
    cve = nil
    attrs.each_index do |i|
      cve = attrs[i][1] if attrs[i][0] == 'name'
    end
    cve
  end

  def my_issue_and_desc_name(name)
    @my_issue && name == 'desc'
  end

  private

  def reset_values
    @my_summary = ''
    @is_desc = false
  end
end
