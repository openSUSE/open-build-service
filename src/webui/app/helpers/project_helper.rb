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

  def rpm_url( project, package, repository )
    "http://#{FRONTEND_HOST}:#{FRONTEND_PORT}/rpm/#{project.name}/#{repository.name}/#{package}.rpm"
  end

  def status_id_for( package, repo, arch )
    "#{package}:#{repo}:#{arch}"
  end

  def watch_link_text
    if @user
      @user.watches?(@project_name) ? "[Don't watch this project]" : "[Watch this project]"
    end
  end

  def format_packstatus_for( repo, arch )
    #logger.debug "starting format_packstatus_for"
    ret = String.new
    #logger.debug "looking for packstatuslist for '#{repo}/#{arch}' (repo/arch)"
    return unless @packstatus.has_element? :packstatuslist

    psl = @packstatus.packstatuslist("@repository='#{repo}' and @arch='#{arch}'")
    #logger.debug "psl is: #{psl.inspect}"
    if psl.nil?
      ret << "n/a<br>"
    else
      psl.each_packstatussummary do |pss|
        ret << "#{pss.status}: #{pss.count}<br>\n"
      end
    end
    #logger.debug "returning: #{ret.inspect}"
    return ret
  end

  def repo_url(project, repo)
    'http://software.opensuse.org/download/' + project.name.sub(':', ':/') + '/' + repo.name
  end
  

end
