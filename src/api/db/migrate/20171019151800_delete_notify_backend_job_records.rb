# frozen_string_literal: true

class DeleteNotifyBackendJobRecords < ActiveRecord::Migration[5.1]
  def up
    Delayed::Job.where("handler like '%ruby/object:EventNotifyBackendJob%'").delete_all
  end
end
