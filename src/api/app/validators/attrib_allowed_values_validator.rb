# Validator for Attrib
class AttribAllowedValuesValidator < ActiveModel::Validator
  def validate(record)
    if record.attrib_type && record.attrib_type.allowed_values.any?
      record.values.each do |value|
        found = false
        record.attrib_type.allowed_values.each do |allowed|
          if allowed.value == value.value
            found = true
            break
          end
        end
        if !found
          record.errors[:values] << "value \'#{value}\' is not allowed. Please use one of: " +
                                    "#{record.attrib_type.allowed_values.map{|av| av.value }.join(', ')}"
        end
      end
    end
  end
end
