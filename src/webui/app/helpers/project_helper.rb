module ProjectHelper

  protected
  
  def watch_link_text
    user.watches?(@project.name) ? "Don't watch this project" : "Watch this project"
  end

  def watch_link_image
    user.watches?(@project.name) ? "magnifier_zoom_out.png" : "magnifier_zoom_in.png"
  end

  def show_status_comment( comment, package, firstfail, comments_to_clear )
    status_comment_html = "".html_safe
    if comment
      status_comment_html = ERB::Util::h(comment)
      if !firstfail
        if @project.can_edit?( session[:login] )
          status_comment_html += " ".html_safe + link_to_remote( image_tag('icons/comment_delete.png', :size => "16x16", :alt => 'Clear'), :update => "comment_#{package.gsub(':', '-')}",
          :url => { :action => :clear_failed_comment, :project => @project, :package => package })
          comments_to_clear << package
        end
      elsif @project.can_edit?( session[:login] )
        status_comment_html += " ".html_safe
        status_comment_html += link_to_remote image_tag('icons/comment_edit.png', :alt => "Edit"), :update => "comment_edit_#{package.gsub(':', '-')}",
          :url => { :action => "edit_comment_form", :comment=> ERB::Util::h(comment), :package => package, :project => @project }
      end 
    elsif firstfail
      if @project.can_edit?( session[:login] )
        status_comment_html += " <span class='unknown_failure'>Unknown build failure ".html_safe + link_to_remote( image_tag('icons/comment_edit.png', :size => "16x16", :alt => "Edit"),
          :update => valid_xml_id("comment_edit_#{package}"),
          :url => { :action => "edit_comment_form", :comment=> "", :package => package, :project => @project } )
        status_comment_html += "</span>".html_safe
      else
        status_comment_html += "<span class='unknown_failure'>Unknown build failure</span>".html_safe
      end
    end
    status_comment_html += "<span id='".html_safe + valid_xml_id("comment_edit_#{package}") + "'></span>".html_safe
  end

  def project_bread_crumb( *args )
    @crumb_list = [
      link_to( 'Projects', :controller => 'project', :action => :list_public),
      link_to( @project, :controller => 'project', :action => :show, :project => @project ),
    ] + args
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
