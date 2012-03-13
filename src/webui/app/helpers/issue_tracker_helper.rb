module IssueTrackerHelper
  # Replace all occurences of the acronym with a link to the upstream issue tracker.
  #
  # Example:
  #
  #   'bnc#100' is replaced with '<a href="https://bugzilla.novell.com/show_bug.cgi?id=100">bnc#100</a>'
  # 
  def self.highlight_issues_in(text)
    # Cache the result, it takes some time to compute it. Use a MD5 sum of the first 100 characters as cache key
    return Rails.cache.fetch("highlighted_issues_#{Digest::MD5.hexdigest(text[0..100])}", :expires_in => 7.days) do
      new_text = text.dup
      IssueTracker.acronyms_with_urls_hash.each do |acronym, urls|
        new_text.gsub!(/#{acronym}\#\d+/).each do |match|
            issue_number = match.split('#', 2)[1]
            "<a href=\"#{urls[:show_url].gsub(/@@@/, issue_number)}\">#{match}</a>"
        end
      end
      new_text
    end
  end
end
