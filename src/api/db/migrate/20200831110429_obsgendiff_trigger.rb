class ObsgendiffTrigger < ActiveRecord::Migration[6.0]
  def up
    safety_assured do
      execute 'ALTER TABLE release_targets modify column `trigger` enum("manual","allsucceeded","maintenance","obsgendiff")'
    end
  end

  def down
    safety_assured do
      execute 'ALTER TABLE release_targets modify column `trigger` enum("manual","allsucceeded","maintenance")'
    end
  end
end
