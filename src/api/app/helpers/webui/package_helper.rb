module Webui::PackageHelper
  def file_url( project, package, filename, revision = nil )
    opts = {}
    if revision
      opts[:rev] = revision
    end
    Package.source_path(project, package, filename, opts)
  end

  def rpm_url( project, package, repository, arch, filename )
    get_frontend_url_for( controller: 'build' ) +
      "/#{project}/#{repository}/#{arch}/#{package}/#{filename}"
  end

  def human_readable_fsize( bytes )
    number_to_human_size bytes
  end

  def title_or_name(package)
    package.title.blank? ? package.name : package.title
  end

  def guess_code_class( filename )
    return 'xml' if %w(_aggregate _link _patchinfo _service).include?(filename) || filename.match(/.*\.service/)
    return 'shell' if filename.match(/^rc[\w-]+$/) # rc-scripts are shell
    return 'python' if filename.match(/^.*rpmlintrc$/)
    return 'makefile' if filename == 'debian.rules'
    return 'baselibs' if filename == 'baselibs.conf'
    return 'spec' if filename.match(/^macros\.\w+/)
    ext = Pathname.new(filename).extname.downcase
    case ext
      when '.group' then return 'xml'
      when '.kiwi' then return 'xml'
      when '.patch', '.dif' then return 'diff'
      when '.pl', '.pm' then return 'perl'
      when '.product' then return 'xml'
      when '.py' then return 'python'
      when '.rb' then return 'ruby'
      when '.tex' then return 'latex'
      when '.js' then return 'javascript'
      when '.sh' then return 'shell'
      when '.spec' then return 'rpm-spec'
      when '.changes' then return 'rpm-changes'
    end
    ext = ext[1..-1]
    return ext if %w(diff php html xml css perl).include? ext
    ''
  end

  include Webui::ProjectHelper

  def package_bread_crumb( *args )
    args.insert(0, link_to_if(params['action'] != 'show', @package,
                              controller: :package, action: :show,
                              project: @project, package: @package ))
    project_bread_crumb( *args )
  end

  def nbsp(text)
    result = "".html_safe
    text.split(" ").each do |text_chunk|
      result << text_chunk
      result << "&nbsp;".html_safe
    end
    result.chomp!("&nbsp;")

    if result.length >= 50
      # Allow break line for very long file names
      result = result.scan(/.{1,50}/).join("<wbr>")
    end
    # We just need to make it a SafeBuffer object again, after calling chomp and join.
    # But at this point we know it truly is html safe
    result.html_safe
  end
end
