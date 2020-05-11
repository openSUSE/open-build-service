module PopulateSphinx
  def populate_sphinx
    ThinkingSphinx::RealTime::Callbacks::RealTimeCallbacks.new(
      self.class.name.underscore.to_sym
    ).after_save(self)
  end
end
