# frozen_string_literal: true

class ConvertNotificationsEventPayloadToJson < ActiveRecord::Migration[5.1]
  def self.up
    Notification20170831143534.transaction do
      Notification20170831143534.all.find_each do |notification|
        json = yaml_to_json(notification.event_payload)
        notification.update_attributes!(event_payload: json)
      end
    end
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end

def yaml_to_json(yaml)
  YAML.safe_load(yaml)
      .traverse do |value|
        if value.is_a? String
          value.force_encoding('UTF-8')
        else
          value
        end
      end
      .to_json
end

# Notification model only for migration in order to avoid errors coming from the serialization in the actual Notification model
class Notification20170831143534 < ::ApplicationRecord
  self.table_name = 'notifications'
  self.inheritance_column = :_type_disabled
end

# Hash extension is used to run force_encoding against each string value in the hash
# in data migration to convert yaml to json serialisation for event payloads
class Hash
  def traverse(&block)
    traverse_value(self, &block)
  end

  private

  def traverse_value(value, &block)
    if value.is_a? Hash
      value.each { |key, sub_value| value[key] = traverse_value(sub_value, &block) }

    elsif value.is_a? Array
      value.map { |element| traverse_value(element, &block) }

    else
      yield(value)

    end
  end
end
