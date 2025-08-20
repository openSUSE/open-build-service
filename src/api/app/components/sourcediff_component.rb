class SourcediffComponent < ApplicationComponent
  attr_accessor :bs_request, :action, :refresh, :diff_to_superseded, :diff_not_cached, :tarlimit

  delegate :diff_label, to: :helpers
  delegate :diff_data, to: :helpers

  def initialize(bs_request:, action:, diff_not_cached:, diff_to_superseded: nil, tarlimit: nil)
    super

    @bs_request = bs_request
    @action = action
    @diff_to_superseded = diff_to_superseded
    @commented_lines = commented_lines
    @diff_not_cached = diff_not_cached
    @tarlimit = tarlimit
  end

  def expandable?(sourcediff)
    return false unless sourcediff.key?('files')

    sourcediff['files'].filter_map do |f, d|
      next if d.dig('diff', 'lines') == d.dig('diff', 'shown')
      next unless d.dig('diff', 'shown') == '0'
      next unless d['state'] == 'changed'

      f
    end.any?
  end

  def commentable
    BsRequestAction.find(@action.id)
  end

  def commented_lines
    commented_lines_indexes = commentable ? commentable.comments.where.not(diff_file_index: nil).select(:diff_file_index, :diff_line_number).distinct.pluck(:diff_file_index, :diff_line_number) : []
    commented_lines_indexes.group_by(&:first).to_h { |key, values| [key, values.collect { |v| v[1] }] }
  end

  def source_package
    return nil unless @action.source_package

    Package.get_by_project_and_name(@action.source_project, @action.source_package, { follow_multibuild: true })
  rescue Package::UnknownObjectError, Project::Errors::UnknownObjectError
    # Ignore these exceptions on purpose
  end

  def target_package
    # For not accepted maintenance incident requests, the package is not there.
    return nil unless @action.target_package

    Package.get_by_project_and_name(@action.target_project, @action.target_package, { follow_multibuild: true })
  rescue Package::UnknownObjectError, Project::Errors::UnknownObjectError
    # Ignore these exceptions on purpose
  end

  def diff_list(sourcediff)
    files = sourcediff['files'].sort_by { |k, _v| sourcediff['filenames'].find_index(k) }.to_h

    files.each_with_index do |(filename, _contents), file_index|
      files[filename]['diff_url'] = request_changes_diff_path(number: @bs_request.number, request_action_id: @action.id,
                                                              filename:, diff_to_superseded:, file_index:, tarlimit: @tarlimit,
                                                              commented_lines: @commented_lines[file_index], filelimit: 0)
    end

    files
  end
end
