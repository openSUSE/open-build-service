# frozen_string_literal: true
class MarkEvents < ActiveRecord::Migration[4.2]
  def up
    add_column :events, :mails_sent, :boolean, default: false
    # all events in existance should have the mail sent out
    Event::Base.update_all(mails_sent: true)

    # unless there is a delayed job for it
    Delayed::Job.where("handler like '%ruby/object:SendEventEmails%'").each do |j|
      next unless j.payload_object.event
      j.payload_object.event.update(mails_sent: false)
    end

    Delayed::Job.where("handler like '%ruby/object:SendEventEmails%'").delete_all
  end

  def down
    remove_column :events, :mails_sent
    # we can't revert the delayed jobs - they are gone
  end
end
