class SourcediffTabComponent < ApplicationComponent
  attr_accessor :bs_request, :action, :active, :index

  delegate :valid_xml_id, to: :helpers
  delegate :request_action_header, to: :helpers
  delegate :diff_label, to: :helpers
  delegate :diff_data, to: :helpers

  def initialize(bs_request:, action:, active:, index:)
    super

    @bs_request = bs_request
    @action = action
    @active = active
    @index = index
  end

  def file_view_path(filename, sourcediff)
    return if sourcediff['files'][filename]['state'] == 'deleted'
    return unless (source_package = Package.find_by_project_and_name(@action[:sprj], @action[:spkg]))
    return unless source_package.file_exists?(filename, { rev: @action[:srev] }.compact)

    diff_params = diff_data(@action[:type], sourcediff)
    diff_params[:project_name] = diff_params[:project]
    diff_params[:package_name] = diff_params[:package]
    project_package_file_path(diff_params.merge(filename: filename))
  end

  def release_info
    @action[:type] == :maintenance_incident && @action[:releaseproject]
  end

  def active_class
    return if @active != @action[:name]

    'active'
  end
end
