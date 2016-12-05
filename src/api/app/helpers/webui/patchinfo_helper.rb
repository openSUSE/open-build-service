module Webui::PatchinfoHelper
  include Webui::ProjectHelper
  def patchinfo_bread_crumb( *args )
    args.insert(0, link_to( @package, action: :show, project: @project, package: @package ))
    project_bread_crumb( *args )
  end

  def issue_link( issue )
    # list issue-names with urls and summary from the patchinfo-file
    # issue[0] = tracker-name
    # issue[1] = issueid
    # issue[2] = issue-url
    # issue[3] = issue-summary

    if issue[0] == "CVE"
      content_tag(:li, link_to("#{issue[1]}", issue[2]) + ": #{issue[3]}")
    else
      content_tag(:li, link_to("#{issue[0]}##{issue[1]}", issue[2]) + ": #{issue[3]}")
    end
  end
end
