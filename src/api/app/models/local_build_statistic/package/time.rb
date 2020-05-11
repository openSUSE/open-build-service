module LocalBuildStatistic
  module Package
    class Time
      include ActiveModel::Model
      attr_accessor :total, :total_unit, :install, :install_unit, :preinstall, :preinstall_unit, :main, :main_unit
    end
  end
end
