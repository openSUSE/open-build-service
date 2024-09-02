module ParsePackageDiff
  def issues_hash(sourcediff)
    ret = {}
    sourcediff.get('issues').elements('issue') do |issue|
      next unless issue['name']

      i = Issue.find_by_name_and_tracker(issue['name'], issue['tracker'], nonfatal: 1)
      next unless i

      issue_infos = i.webui_infos
      issue_infos[:state] = issue['state'] if issue['state']

      ret[issue['label']] = issue_infos
    end
    ret
  end

  def parse_one_diff(sourcediff)
    # Sort files into categories by their ending and add all of them to a hash. We
    # will later use the sorted and concatenated categories as key index into the per action file hash.
    changes_file_keys = []
    spec_file_keys = []
    patch_file_keys = []
    other_file_keys = []
    files_hash = {}

    sourcediff.get('files').elements('file') do |file|
      filename = if file['new']
                   file['new']['name']
                 else # in case of deleted files
                   file['old']['name']
                 end
      files_hash[filename] = file
      if filename.include?('/')
        other_file_keys << filename
        next
      end
      if filename.ends_with?('.spec')
        spec_file_keys << filename
      elsif filename.ends_with?('.changes')
        changes_file_keys << filename
      elsif /.*.(patch|diff|dif)/.match?(filename)
        patch_file_keys << filename
      else
        other_file_keys << filename
      end
    end

    {
      'old' => sourcediff['old'],
      'new' => sourcediff['new'],
      'filenames' => changes_file_keys.sort + spec_file_keys.sort + patch_file_keys.sort + other_file_keys.sort,
      'files' => files_hash,
      'issues' => issues_hash(sourcediff)
    }
  end

  def sorted_filenames_from_sourcediff(sd)
    return [{}] if sd.blank?

    sd = "<diffs>#{sd}</diffs>"
    Xmlhash.parse(sd).elements('sourcediff').map do |sourcediff|
      parse_one_diff(sourcediff)
    end
  end
end
