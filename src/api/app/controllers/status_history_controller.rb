require_dependency 'status_helper'

class StatusHistoryController < ApplicationController
  def show
    required_parameters :hours, :key

    @samples = [params[:samples].to_i, 1].max
    @values = StatusHistory.history_by_key_and_hours(params[:key], params[:hours])
  end
end
