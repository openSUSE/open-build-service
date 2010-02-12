module ProjectHelper
  def format_target_list( project )
    result = ""
    result += "<ul>\n"
    if @project.has_element? :target
      @project.each_target do |target|
        result += "<li><b>#{target.platform.name}</b>\n"
        result += format_arch_list( target )
        result += "</li>\n"
      end
    end
    result += "</ul>\n"
  end

  def format_arch_list( target )
    result = ""
    if target.has_element? :arch
      result += "<ul>\n"
      target.each_arch do |arch|
        result += "<li>#{arch}</li>\n"
      end
      result += "</ul>\n"
    end
  end

  def repo_status_for( repo, arch )
    @repostatushash[repo][arch] || ActiveXML::XMLNode.new("<status code='-'/>")
  end

  def status_for( repo, arch, package )
    @statushash[repo][arch][package] || ActiveXML::XMLNode.new("<status code='-' package='#{package}'/>")
  end

  def status_id_for( repo, arch, package )
    "#{package}:#{repo}:#{arch}"
  end

  def arch_repo_table_cell(repo, arch, packname)
    status = status_for(repo, arch, packname)
    status_id = status_id_for( repo, arch, packname)
    link_title = status.has_element?(:details) ? status.details.to_s : nil
    theclass="status_" + status.code.gsub(' ','_') 
    out = "<td id='#{status_id}' class='#{theclass}'>"
    if ["expansion error", "broken", "blocked"].include? status.code 
      out += link_to status.code, "javascript:alert('#{link_title}')", :title => link_title
    elsif ["disabled","-"].include? status.code
      out += status.code
    else
      out += link_to status.code.gsub(/\s/, "&nbsp;"), {:action => :live_build_log,
          :package => packname, :project => @project.to_s, :arch => arch,
          :controller => "package", :repository => repo}, {:title => link_title}
    end 
    return out + "</td>"
  end

  def watch_link_text
    user.watches?(@project.name) ? "[Don't watch this project]" : "[Watch this project]"
  end

  def watch_link_image
    user.watches?(@project.name) ? "dontwatch.png" : "watch.png"
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

  def simple_repo_button_to( label, opt={} )
    reponame = String.new
    reponame << BASE_NAMESPACE << ":" if BASE_NAMESPACE
    reponame << opt[:repo]

    defaults = {
      :arch => [],
      :project => @project,
      :action => :save_target
    }
    opt = defaults.merge opt

    btn_to_opt = {
      :targetname => opt[:reponame],
      :project => opt[:project],
      :action => opt[:action]
    }

    unless reponame == ""
      btn_to_opt[:platform] = reponame
    end

    opt[:arch].each do |arch|
      btn_to_opt["arch[#{arch}]"] = ""
    end

    if @project and @project.has_element?("repository[@name='#{opt[:reponame]}']")
      return button_to(label, btn_to_opt, {:disabled => true})
    else
      return button_to(label, btn_to_opt)
    end
  end

  def draggable_repo( label, opt={} )
    out = String.new
    out << "<li id='repo_#{label}' class='draggable_sub_element'>#{label}</li>"
    out << draggable_element("repo_#{label}", :revert => true, :snap => true,
             :reverteffect => "function(element, top_offset, left_offset) {
               new Effect.Move( element, {x: -left_offset, y: -top_offset, duration: 0})
             }")
    out
  end

  def flag_status(flag)
    image = title = ""

    if flag.nil?
      return "n.a."
    end

    if flag.explicit_set?
      if flag.disabled?
	image = "#{flag.name}_disabled_blue.png"
	title = "#{flag.name} disabled"
      else
	image = "#{flag.name}_enabled_blue.png"
	title = "#{flag.name} enabled"
      end
    else
      if flag.disabled?
	image = "#{flag.name}_disabled_grey.png"
	title = "#{flag.name} disabled, through #{flag.implicit_setter.description}"
      else
	image = "#{flag.name}_enabled_grey.png"
	title = "#{flag.name} enabled, through #{flag.implicit_setter.description}"
      end
    end
    
    id = "%s_%s" % [ flag.name, flag.id.gsub(/[:.]/, "_") ]

    out = "<span id='%s'>" % id 
    out += link_to_remote_if @project.is_maintainer?( session[:login] ), image_tag(image,:title => title, :class => "flagimage"),
      :loading => 'stopit = 0; hideflags();',
      :complete => 'showflags()',
      :url => { :action => "update_flag", :project => @project,
      :flag_name => flag.name, :repo => flag.repository, :arch => flag.architecture,
      :status => flag.status, :flag_id => flag.id  }
    out += "</span>"
  end

  def project_tab(text, opts)
    opts[:project] = @project.to_s
    if @current_action.to_s == opts[:action].to_s
      link = "<li id='current_tab'>"
    else
      link = "<li>"
    end
    link + link_to(text, opts) + "</li>"
  end

  def show_status_comment( comment, package, firstfail, comments_to_clear )
    status_comment_html = ""
    if comment
      status_comment_html = comment
      if !firstfail
        status_comment_html += "(" + link_to('Clear Comment', :action => :clear_failed_comment, :project => @project, :package => package) + ")"
        comments_to_clear << package
      else
        status_comment_html += link_to_remote image_tag('edit.png', :alt => "Edit"), :update => "comment_edit_#{package}",
          :url => { :action => "edit_comment_form", :comment=> comment, :package => package, :project => @project }
      end 
    elsif firstfail
      status_comment_html += "<div class='unknown_failure'>Unknown build failure " + link_to_remote( image_tag('edit.png', :alt => "Edit"), :update => "comment_edit_#{package}",
        :url => { :action => "edit_comment_form", :comment=> "", :package => package, :project => @project } )
      status_comment_html += "</div>"
    end
    status_comment_html += "<div id='comment_edit_#{package}'></div>"
  end


end
