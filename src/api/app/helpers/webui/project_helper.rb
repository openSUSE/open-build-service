module Webui::ProjectHelper
  include Webui::WebuiHelper

  protected

  def show_status_comment(comment, package, firstfail, comments_to_clear)
    status_comment_html = ''.html_safe
    if comment
      # TODO: Port _to_remote helpers to jQuery
      status_comment_html = ERB::Util::h(comment)
      if !firstfail
        if User.current.can_modify_project?(@project.api_obj)
          status_comment_html += ' '.html_safe + link_to(image_tag('comment_delete.png', size: '16x16', alt: 'Clear'),
                                                         {action: :clear_failed_comment, project: @project,
                                                          package: package, update: valid_xml_id("comment_#{package}")},
                                                         remote: true)
          comments_to_clear << package
        end
      elsif User.current.can_modify_project?(@project.api_obj)
        status_comment_html += ' '.html_safe
        status_comment_html += link_to(image_tag('comment_edit.png', alt: 'Edit'),
                                       {action: 'edit_comment_form', comment: comment,
                                        package: package, project: @project,
                                        update: valid_xml_id("comment_edit_#{package}")},
                                       remote: true)
      end
    elsif firstfail
      if User.current.can_modify_project?(@project.api_obj)
        status_comment_html += " <span class='unknown_failure'>Unknown build failure ".html_safe +
            link_to(image_tag('comment_edit.png', size: '16x16', alt: 'Edit'),
                    {action: 'edit_comment_form', comment: '', package: package,
                     project: @project, update: valid_xml_id("comment_edit_#{package}")},
                    remote: true)
        status_comment_html += '</span>'.html_safe
      else
        status_comment_html += "<span class='unknown_failure'>Unknown build failure</span>".html_safe
      end
    end
    status_comment_html + "<span id='".html_safe + valid_xml_id("comment_edit_#{package}") + "'></span>".html_safe
  end

  def project_bread_crumb(*args)
    @crumb_list = [link_to('Projects', project_list_public_path)]
    return if @spider_bot
    # FIXME: should also work for remote
    if @project && @project.kind_of?(Project) && !@project.new_record?
      prj_parents = nil
      if @namespace # corner case where no project object is available
        prj_parents = Project.parent_projects(@namespace)
      else
        # FIXME: Some controller's @project is a Project object whereas other's @project is a String object.
        prj_parents = Project.parent_projects(@project.to_s)
      end
      project_list = []
      prj_parents.each do |name, short_name|
        project_list << link_to(short_name, project_show_path(project: name))
      end
      @crumb_list << project_list if project_list.length > 0
    end
    @crumb_list = @crumb_list + args
  end

  def format_seconds(secs)
    secs = Integer(secs)
    if secs < 3600
      '0:%02d' % (secs / 60)
    else
      hours = secs / 3600
      secs -= hours * 3600
      '%d:%02d' % [hours, secs / 60]
    end
  end

  def rebuild_time_col(package)
    return '' if package.blank?
    btime = @timings[package][0]
    link_to(h(package), controller: :package, action: :show, project: @project, package: package) + ' ' + format_seconds(btime)
  end

  def short_incident_name(incident)
    re = Regexp.new("#{@project.name}\:(.*)")
    match = incident.name.match(re)
    return match[1] if match.length > 1
    match[0]
  end

  def patchinfo_rating_color(rating)
    Patchinfo::RATING_COLORS[rating.to_s] || ''
  end

  def patchinfo_category_color(category)
    Patchinfo::CATEGORY_COLORS[category.to_s] || ''
  end

  def incident_issue_color(patchinfo_issues, package_issues)
    return 'red' if package_issues.zero?
    if patchinfo_issues == package_issues
      return 'green'
    elsif patchinfo_issues < package_issues
      return 'olive'
    else
      return 'red'
    end
  end

  STATE_ICONS = {
      'new'      => 'flag_green',
      'review'   => 'flag_yellow',
      'declined' => 'flag_red'
  }

  def map_request_state_to_flag(state)
    STATE_ICONS[state.to_s] || ''
  end

  def escape_list(list)
    # The input list is not html_safe because it's
    # user input which we should never trust!!!
    list.map { |p|
      "['".html_safe +
          escape_javascript(p) +
          "']".html_safe
    }.join(',').html_safe
  end
end
