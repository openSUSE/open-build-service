module LocalBuildStatistic
  module Package
    class Disk
      include ActiveModel::Model
      attr_accessor :size, :unit, :io_requests, :io_sectors
    end
  end
end
