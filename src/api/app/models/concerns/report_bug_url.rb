module ReportBugUrl
  extend ActiveSupport::Concern

  def report_bug_or_bugzilla_url
    return report_bug_url if Flipper.enabled?(:foster_collaboration, User.possibly_nobody) && report_bug_url.present?

    return nil if ::Configuration.bugzilla_url.blank?

    bugowners_emails_list = retrieve_bugowners_emails_list
    return nil if bugowners_emails_list.blank?

    description = if is_a?(Package)
                    "#{project.name}/#{name}: Bug"
                  else
                    "#{name}: Bug"
                  end
    bugzilla_url(bugowners_emails_list, description)
  end

  private

  def retrieve_bugowners_emails_list
    return (bugowner_emails + project.bugowner_emails).uniq if is_a?(Package)

    bugowner_emails
  end

  def bugzilla_url(email_list, desc)
    assignee = email_list.first if email_list
    cc = "&cc=#{email_list[1..].join('&cc=')}" if email_list.length > 1 && email_list

    Addressable::URI.escape(
      "#{::Configuration.bugzilla_url}/enter_bug.cgi?classification=7340&product=openSUSE.org" \
      "&component=3rd party software&assigned_to=#{assignee}#{cc}&short_desc=#{desc}"
    )
  end
end
