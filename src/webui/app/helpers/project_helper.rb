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
    @user.watches?(@project_name) ? "[Don't watch this project]" : "[Watch this project]"
  end
end
