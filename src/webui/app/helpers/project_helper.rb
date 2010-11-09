module ProjectHelper

  protected
  
  def watch_link_text
    user.watches?(@project.name) ? "Don't watch this project" : "Watch this project"
  end

  def watch_link_image
    user.watches?(@project.name) ? "magnifier_zoom_out.png" : "magnifier_zoom_in.png"
  end

  def format_packstatus_for( repo, arch )
    return if @buildresult.nil?
    return unless @buildresult.has_element? :result
    ret = String.new
    
    result = @buildresult.result("@repository='#{repo}' and @arch='#{arch}'")
    if result.nil?
      ret << "n/a<br>"
    else
      if result.has_attribute? "state"
        if result.has_attribute? "dirty"
          ret << "State: outdated(" << result.state << ")"
        else
          ret << "State: " << result.state
        end
        ret << "<br>"
      end
      result.summary.each_statuscount do |scnt|
        ret << link_to("#{scnt.code}:&nbsp;#{scnt.count}", :action => :monitor, 'repo_' + repo => 1, 'arch_' + arch => 1, :project => params[:project], scnt.code => 1, :defaults => 0)
        ret << "<br>\n"
      end
    end

    return ret
  end

  def project_tab(text, opts)
    opts[:project] = @project.to_s
    if @current_action.to_s == opts[:action].to_s
      link = "<li class='selected'>"
    else
      link = "<li>"
    end
    link + link_to(text, opts) + "</li>"
  end

  def show_status_comment( comment, package, firstfail, comments_to_clear )
    status_comment_html = ""
    if comment
      status_comment_html = ERB::Util::h(comment)
      if !firstfail
        if @project.can_edit?( session[:login] )
          status_comment_html += " " + link_to_remote( image_tag('icons/comment_delete.png', :size => "16x16", :alt => 'Clear'), :update => "comment_#{package.gsub(':', '-')}",
          :url => { :action => :clear_failed_comment, :project => @project, :package => package })
          comments_to_clear << package
        end
      elsif @project.can_edit?( session[:login] )
        status_comment_html += " "
        status_comment_html += link_to_remote image_tag('icons/comment_edit.png', :alt => "Edit"), :update => "comment_edit_#{package.gsub(':', '-')}",
          :url => { :action => "edit_comment_form", :comment=> ERB::Util::h(comment), :package => package, :project => @project }
      end 
    elsif firstfail
      if @project.can_edit?( session[:login] )
        status_comment_html += " <span class='unknown_failure'>Unknown build failure " + link_to_remote( image_tag('icons/comment_edit.png', :size => "16x16", :alt => "Edit"),
          :update => valid_xml_id("comment_edit_#{package}"),
          :url => { :action => "edit_comment_form", :comment=> "", :package => package, :project => @project } )
        status_comment_html += "</span>"
      else
        status_comment_html += "<span class='unknown_failure'>Unknown build failure</span>"
      end
    end
    status_comment_html += "<span id='" + valid_xml_id("comment_edit_#{package}") + "'></span>"
  end

  def project_bread_crumb( *args )
    @crumb_list = [link_to('Projects', :controller => 'project', :action => :list_public)]
    if @project.class == String
      parts = @project.split(":")
    else
      parts = @project.name.split(":")
    end
    for x in 1 .. parts.length - 1 do
      prj = parts[0..x].join(":")
      name = ":" + parts[x]
      name = parts[0] + name if x == 1
      @crumb_list += [link_to(name, :controller => 'project', :action => :show, :project => prj)]
    end
    @crumb_list += args
  end

  def format_seconds( secs ) 
    secs = Integer(secs)
    if secs < 3600
      "0:%02d" % (secs / 60)
    else
      hours = secs / 3600
      secs -= hours * 3600
      "%d:%02d" % [ hours, secs / 60]
    end
  end

  def rebuild_time_col( package )
     return '' if package.blank?
     btime, etime = @timings[package]
     link_to( h(package), :controller => :package, :action => :show, :project => @project, :package => package) + " " + format_seconds(btime)
  end
end
