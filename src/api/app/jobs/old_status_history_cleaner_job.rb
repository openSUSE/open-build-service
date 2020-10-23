class OldStatusHistoryCleanerJob < ApplicationJob
  queue_as :quick

  def perform
    status_history_until(1.year.ago.to_i).delete_all
  end

  private

  def status_history_until(ending_date)
    StatusHistory.where('time < ?', ending_date)
  end
end
