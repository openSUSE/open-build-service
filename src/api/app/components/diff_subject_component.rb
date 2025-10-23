class DiffSubjectComponent < ApplicationComponent
  attr_reader :state, :old_filename, :new_filename

  def initialize(state:, file_info:)
    super()

    @state = state
    @old_filename = file_info.dig('old', 'name')
    @new_filename = file_info.dig('new', 'name')
  end

  def badge
    return 'text-bg-success' if @state == 'added'
    return 'text-bg-danger' if @state == 'deleted'

    'text-bg-info'
  end

  def changed_filename
    return @new_filename unless @old_filename
    return @old_filename unless @new_filename
    return @new_filename if @old_filename == @new_filename

    "#{@old_filename} -> #{@new_filename}"
  end
end
