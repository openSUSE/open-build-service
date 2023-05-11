# frozen_string_literal: true

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

    diff_params = diff_data(@action[:type], sourcediff)
    package_view_file_path(diff_params.merge(filename: filename))
  end

  def release_info
    @action[:type] == :maintenance_incident && @action[:releaseproject]
  end

  def active_class
    return if @active != @action[:name]

    'active'
  end
end
