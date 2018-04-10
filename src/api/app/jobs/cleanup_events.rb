# frozen_string_literal: true

class CleanupEvents < ApplicationJob
  def perform
    Event::Base.where(mails_sent: true, undone_jobs: 0).delete_all
  end
end
