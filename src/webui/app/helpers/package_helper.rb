module PackageHelper

  protected
  
  def build_log_url( project, package, repository, arch )
    get_frontend_url_for( :controller => 'result' ) +
      "/#{project}/#{repository}/#{package}/#{arch}/log"
  end


  def file_url( project, package, filename, revision=nil )
    url = get_frontend_url_for( :controller => '') +
      "source/#{project}/#{package}/#{CGI.escape filename}?"
    url += "rev=#{CGI.escape revision}&" if revision
    return url
  end


  def rpm_url( project, package, repository, arch, filename )
    get_frontend_url_for( :controller => 'build' ) +
      "/#{project}/#{repository}/#{arch}/#{package}/#{filename}"
  end

  def human_readable_fsize( bytes )
    number_to_human_size bytes
  end

  def guess_code_class( filename )
    return 'xml' if ['_aggregate', '_link', '_patchinfo', '_service'].include?(filename) || filename.match(/.*\.service/)
    return "shell" if filename.match(/^rc[\w-]+$/) # rc-scripts are shell
    return "python" if filename.match(/^.*rpmlintrc$/)
    return "makefile" if filename == "debian.rules"
    return "baselibs" if filename == "baselibs.conf"
    return "spec" if filename.match(/^macros\.\w+/)
    ext = Pathname.new(filename).extname.downcase
    case ext
      when ".group" then return "xml"
      when ".kiwi" then return "xml"
      when ".patch", ".dif" then return "diff"
      when ".pl", ".pm" then return "perl"
      when ".product" then return "xml"
      when ".py" then return "python"
      when ".rb" then return "ruby"
      when ".tex" then return "latex"
      when ".js" then return "javascript"
      when ".sh" then return "shell"
    end
    ext = ext[1..-1]
    return ext if ['diff', 'php', 'html', 'xml', 'css', 'perl'].include? ext
    return ''
  end

  include ProjectHelper

  def package_bread_crumb( *args )
    args.insert(0, link_to_if(params['action'] != 'show', @package, :controller => :package, :action => :show, :project => @project, :package => @package ))
    args.insert(0, link_to('Packages', :controller => 'project', :action => 'show', :project => @project))
    project_bread_crumb( *args )
  end

  def nbsp(text)
    return text.gsub(' ', "&nbsp;")
  end

  # FIXME2.4: this is copying stuff done in the API as bs_reqest_action - to be used!!
  def sorted_filenames_from_sourcediff(sd)
    # Sort files into categories by their ending and add all of them to a hash. We
    # will later use the sorted and concatenated categories as key index into the per action file hash.
    changes_file_keys, spec_file_keys, patch_file_keys, other_file_keys = [], [], [], []
    files_hash, issues_hash = {}, {}

    parsed_sourcediff = []

    sd = "<diffs>" + sd + "</diffs>"
    Xmlhash.parse(sd).elements('sourcediff') do |sourcediff|
      
      sourcediff.get('files').elements('file') do |file|
        if file['new']
          filename = file['new']['name']
        else # in case of deleted files
          filename = file['old']['name']
        end

        if filename.include?('/')
          other_file_keys << filename
        else
          if filename.ends_with?('.spec')
            spec_file_keys << filename
          elsif filename.ends_with?('.changes')
            changes_file_keys << filename
          elsif filename.match(/.*.(patch|diff|dif)/)
            patch_file_keys << filename
          else
            other_file_keys << filename
          end
        end
        files_hash[filename] = file
      end
      
      if sourcediff['issues']
        sourcediff.elements('issues').each do |issue|
          next unless issue['name']
          issues_hash[issue['label']] = Issue.find_cached(issue['name'], :tracker => issue['tracker'])
        end
      end
      
      parsed_sourcediff << {
        'old' => sourcediff['old'],
        'new' => sourcediff['new'],
        'filenames' => changes_file_keys.sort + spec_file_keys.sort + patch_file_keys.sort + other_file_keys.sort,
        'files' => files_hash,
        'issues' => issues_hash
      }
    end
    return parsed_sourcediff
  end
  
end

