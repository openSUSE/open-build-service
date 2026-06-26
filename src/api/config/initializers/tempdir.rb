class Dir
  def self.tmpdir
    Rails.root.join('tmp').to_s
  end
end
