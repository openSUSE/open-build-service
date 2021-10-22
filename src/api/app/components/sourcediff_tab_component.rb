# frozen_string_literal: true

class SourcediffTabComponent < ApplicationComponent
  attr_accessor :bs_request, :action, :active, :index, :refresh

  def initialize(bs_request:, action:, active:, index:, refresh:)
    super

    @bs_request = bs_request
    @action = action
    @active = active
    @index = index
    @refresh = refresh
  end

  def file_view_path(filename, sourcediff)
    return if sourcediff['files'][filename]['state'] == 'deleted'

    diff_params = helpers.diff_data(@action[:type], sourcediff)
    Rails.application.routes.url_helpers.package_view_file_path(diff_params.merge(filename: filename))
  end

  def release_info
    @action[:type] == :maintenance_incident && @action[:releaseproject]
  end

  def active_class
    return if @active != @action[:name]

    'active'
  end
end
