module Webui::PatchinfoHelper
  def patchinfo_header(patchinfo, package_names)
    list = package_names.to_sentence
    text = "Update for #{truncate(list, length: 40)}"
    capture_haml do
      header_title(patchinfo, text, list)
      header_subtitle(patchinfo.summary)
    end
  end

  def patchinfo_issue_link(tracker, number, url)
    link_text = "#{tracker}##{number}"
    link_url = url

    # TODO: unify the treatment of CVE issues all over the code
    if tracker == 'cve'
      issue_tracker = IssueTracker.find_by(kind: 'cve')
      link_text = "#{tracker.upcase}-#{number}"
      link_url = issue_tracker.show_url.gsub('@@@', "CVE-#{number}")
    end

    link_to(link_text, link_url, target: :_blank, rel: 'noopener')
  end

  private

  def header_title(patchinfo, text, list)
    content_tag(:h3) do
      content_tag(:span, text, title: list)
      content_tag(:span, patchinfo.category, class: "badge badge-category #{patchinfo.category}", title: 'Category of this patchinfo')
      content_tag(:span, patchinfo.rating, class: "badge badge-rating #{patchinfo.rating}", title: 'Rating of this patchinfo')
    end
  end

  def header_subtitle(summary)
    content_tag(:div, summary, class: 'mb-3 text-muted') if summary.present?
  end
end
