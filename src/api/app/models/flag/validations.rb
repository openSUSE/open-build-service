module Flag::Validations
  extend ActiveSupport::Concern

  included do
    validate :validate_no_overlapping_flags
  end

  private

  def validate_no_overlapping_flags
    flags = self.flags.map { |flag| "#{flag.flag}-#{flag.architecture_id}-#{flag.repo}" }
    errors.add(:flags, 'Duplicated flags') if flags.size != flags.uniq.size
  end
end
