require Rails.root.join('db/data/20261015120000_move_jobs_out_of_quick_queue.rb')

RSpec.describe MoveJobsOutOfQuickQueue, type: :migration do
  def create_job(job_class, queue)
    Delayed::Job.create!(queue: queue, handler: "job_data:\n  job_class: #{job_class}\n  queue_name: #{queue}\n")
  end

  describe 'up' do
    let!(:sync_upstream_job) { create_job('SyncUpstreamPackageVersionJob', 'quick') }
    let!(:update_packages_job) { create_job('UpdatePackagesIfDirtyJob', 'quick') }
    let!(:measurements_job) { create_job('MeasurementsJob', 'quick') }
    let!(:worker_measurements_job) { create_job('WorkerMeasurementsJob', 'quick') }
    let!(:unrelated_job) { create_job('SomeOtherJob', 'quick') }
    let!(:job_in_other_queue) { create_job('SyncUpstreamPackageVersionJob', 'default') }

    before do
      MoveJobsOutOfQuickQueue.new.up
    end

    it { expect(sync_upstream_job.reload.queue).to eq('slow_user') }
    it { expect(update_packages_job.reload.queue).to eq('quick_user') }
    it { expect(measurements_job.reload.queue).to eq('internal') }
    it { expect(worker_measurements_job.reload.queue).to eq('internal') }
    it { expect(unrelated_job.reload.queue).to eq('quick') }
    it { expect(job_in_other_queue.reload.queue).to eq('default') }
  end
end
