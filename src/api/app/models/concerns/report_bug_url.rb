module ReportBugUrl
  extend ActiveSupport::Concern

  def report_bug_or_bugzilla_url
    return report_bug_url if Flipper.enabled?(:foster_collaboration, User.possibly_nobody) && report_bug_url.present?

    return nil if ::Configuration.bugzilla_url.blank?

    return nil if bugowner_emails.blank?

    description = if is_a?(Package)
                    "#{project.name}/#{name}: Bug"
                  else
                    "#{name}: Bug"
                  end
    bugzilla_url(bugowner_emails, description)
  end

  private

  def bugzilla_url(email_list, desc)
    assignee = email_list.first
    cc = "&cc=#{email_list[1..].join('&cc=')}" if email_list.length > 1

    Addressable::URI.escape(
      "#{::Configuration.bugzilla_url}/enter_bug.cgi?classification=7340&product=openSUSE.org" \
      "&component=3rd party software&assigned_to=#{assignee}#{cc}&short_desc=#{desc}"
    )
  end
end
