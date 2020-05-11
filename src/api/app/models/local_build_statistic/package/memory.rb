module LocalBuildStatistic
  module Package
    class Memory
      include ActiveModel::Model
      attr_accessor :size, :unit
    end
  end
end
