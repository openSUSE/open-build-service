# frozen_string_literal: true
class DropLastEventsRowFromBackendInfo < ActiveRecord::Migration[5.1]
  def change
    BackendInfo.where(key: 'lastevents_nr').destroy_all
  end
end
