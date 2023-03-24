class DiffSubjectComponent < ApplicationComponent
  attr_reader :state, :old_filename, :new_filename

  def initialize(state:, old_filename:, new_filename:)
    super
    @state = state
    @old_filename = old_filename
    @new_filename = new_filename
  end

  def badge
    return 'text-bg-success' if @state == 'added'
    return 'text-bg-danger' if @state == 'deleted'

    'text-bg-info'
  end

  def changed_filename
    return @new_filename unless ['changed', 'renamed'].include?(@state)
    return @new_filename if @old_filename == @new_filename
    return @new_filename unless @old_filename

    "#{@old_filename} -> #{@new_filename}"
  end
end
