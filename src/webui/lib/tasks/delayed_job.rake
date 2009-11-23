#require 'delayed_plots.rb'

namespace :jobs do
  desc "Inject a job to render the history of 24h"
  task(:render24 => :environment) { Delayed::Job.enqueue DelayedPlots.new(24) }
  
  desc "Inject a job to render the history of 72h"
  task(:render72 => :environment) { Delayed::Job.enqueue DelayedPlots.new(72) }

  desc "Inject a job to render the history of a week"
  task(:render168 => :environment) { Delayed::Job.enqueue DelayedPlots.new(168) }

end
