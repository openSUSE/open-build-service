class RequestDiffCacher
  def self.call(action, diff_to_superseded:)
    return unless action.diff_not_cached(diff_to_superseded: diff_to_superseded)

    job = Delayed::Job.where('handler LIKE ?', "%job_class: BsRequestActionWebuiInfosJob%#{action.to_global_id.uri}%").count
    BsRequestActionWebuiInfosJob.perform_later(action) if job.zero?
  end
end
