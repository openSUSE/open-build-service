# Validator for Attrib
class AttribValueLengthValidator < ActiveModel::Validator
  def validate(record)
    if record.attrib_type && record.attrib_type.value_count && record.attrib_type.value_count != record.values.length
      record.errors[:values] << "has #{record.values.length} values, but only #{record.attrib_type.value_count} are allowed"
    end
  end
end
