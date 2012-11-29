module PatchinfoHelper
  include ProjectHelper
  def patchinfo_bread_crumb( *args )
    args.insert(0, link_to( @package, :action => :show, :project => @project, :package => @package ))
    project_bread_crumb( *args )
  end

  def create_issue_list( *args )
    unless @issues.blank?
      issue_list = ""
      issue_list += "<ul>"
      @issues.each do |issue| 
        #issue[0] = tracker-name
        #issue[1] = issue-id
        #issue[2] = issue-url
        #issue[3] = issue-summary
        if issue[0] == "CVE"
          issue_list += "<li>" + link_to("#{issue[1]}", issue[2]) + ": #{issue[3]}" + "</li>"
        else
          issue_list += "<li>" + link_to("#{issue[0]}##{issue[1]}", issue[2]) + ": #{issue[3]}" + "</li>"
        end
      end
      issue_list += "</ul>"
      issue_list.html_safe
    end
  end
end
