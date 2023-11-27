# HappyMapper extension to support TrueClass casting and parsing properly
module HappyMapper
  module SupportedTypes
    register_type TrueClass do
      true
    end
  end
end

module TrueClassMapper
  def apply_on_save_action(item, value)
    value = super(item, value)
    return value unless item&.type == TrueClass

    value ? '' : nil
  end
end

HappyMapper.prepend(TrueClassMapper)
