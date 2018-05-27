module Webui::PackageHelper
  def file_url(project, package, filename, revision = nil)
    opts = {}
    opts[:rev] = revision if revision
    Package.source_path(project, package, filename, opts)
  end

  def rpm_url(project, package, repository, arch, filename)
    get_frontend_url_for(controller: 'build') +
      "/#{project}/#{repository}/#{arch}/#{package}/#{filename}"
  end

  def human_readable_fsize(bytes)
    number_to_human_size bytes
  end

  def title_or_name(package)
    package.title.blank? ? package.name : package.title
  end

  def guess_code_class(filename)
    return 'xml' if filename.in?(['_aggregate', '_link', '_patchinfo', '_service']) || filename =~ /.*\.service/
    return 'shell' if filename =~ /^rc[\w-]+$/ # rc-scripts are shell
    return 'python' if filename =~ /^.*rpmlintrc$/
    return 'makefile' if filename == 'debian.rules'
    return 'baselibs' if filename == 'baselibs.conf'
    return 'spec' if filename =~ /^macros\.\w+/
    return 'dockerfile' if filename =~ /^(D|d)ockerfile.*$/

    ext = Pathname.new(filename).extname.downcase
    case ext
    when '.group', '.kiwi', '.product' then 'xml'
    when '.patch', '.dif' then 'diff'
    when '.pl', '.pm' then 'perl'
    when '.py' then 'python'
    when '.rb' then 'ruby'
    when '.tex' then 'latex'
    when '.js' then 'javascript'
    when '.sh' then 'shell'
    when '.spec' then 'rpm-spec'
    when '.changes' then 'rpm-changes'
    when '.diff', '.php', '.html', '.xml', '.css', '.perl' then ext[1..-1]
    else ''
    end
  end

  include Webui::ProjectHelper

  def project_parents
    return [] if @spider_bot || !@project || !@project.is_a?(Project) || @project.new_record?

    if @namespace # corner case where no project object is available
      Project.parent_projects(@namespace)
    else
      # FIXME: Some controller's @project is a Project object whereas other's @project is a String object.
      Project.parent_projects(@project.to_s)
    end
  end

  def package_bread_crumb(*args)
    args.insert(0, link_to_if(params['action'] != 'show', @package,
                              controller: :package, action: :show,
                              project: @project, package: @package))
    project_bread_crumb(*args)
  end

  def nbsp(text)
    result = ''.html_safe
    text.split(' ').each do |text_chunk|
      result << text_chunk
      result << '&nbsp;'.html_safe
    end
    result.chomp!('&nbsp;')

    if result.length >= 50
      # Allow break line for very long file names
      result = result.scan(/.{1,50}/).join('<wbr>')
    end
    # We just need to make it a SafeBuffer object again, after calling chomp and join.
    # But at this point we know it truly is html safe
    result.html_safe
  end

  def humanize_time(seconds)
    [[60, :s], [60, :m], [24, :h]].map do |count, name|
      if seconds > 0
        seconds, n = seconds.divmod(count)
        "#{n.to_i}#{name}"
      end
    end.compact.reverse.join(' ')
  end

  def repo_type_and_priority(repository)
    [repository.repo_type, repository.priority].compact.join(', Priority: ')
  end

  def uploadable?(filename, architecture)
    ::Cloud::UploadJob.new(filename: filename, arch: architecture).uploadable?
  end
end
