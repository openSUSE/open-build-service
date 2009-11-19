class DropBackgroundrbAgain < ActiveRecord::Migration
  def self.up
	drop_table :bdrb_job_queues
  end

  def self.down
	# create a dummy table here to make rollback work
	create_table :bdrb_job_queues do |t|
           t.column :args, :text
        end
  end
end
