class PackageBuildReason
  include ActiveModel::Model

  validates :explain, :time, presence: true
  attr_accessor :explain, :oldsource, :packagechange
  attr_writer :time

  def time
    Time.at(@time.to_i)
  end
end
