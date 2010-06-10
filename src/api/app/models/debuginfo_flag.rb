class DebuginfoFlag < Flag
  belongs_to :db_project
  belongs_to :db_package
  belongs_to :architecture

  def self.default_state
    return :disabled
  end
end
