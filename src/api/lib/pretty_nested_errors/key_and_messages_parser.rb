module PrettyNestedErrors
  class KeyAndMessagesParser
    NESTED_ERROR_REGEX = /(\w+\[\d+\]\.)+(\w+)/
    HAS_ONE_ERROR_REGEX = /(\w+)\.(\w+)/

    def initialize(base_model, key, messages, nested_error_messages, nested_error_groupings)
      @base_model = base_model
      @key = key
      @messages = messages
      @nested_error_messages = nested_error_messages
      @nested_error_groupings = nested_error_groupings
    end

    # Parse the errors on the model into a nested hash based with keys based on the lambda
    # set in the base model for each association
    def parse
      if @key.match?(NESTED_ERROR_REGEX)
        parsed_key = @key.match(NESTED_ERROR_REGEX)

        association_invalid_column = parsed_key.to_a.last
        nested_resources_and_indexes = @key.to_s.scan(/(\w+)\[(\d+)\]\./)

        parse_error_message_for_nested(nested_resources_and_indexes, association_invalid_column)

      elsif @key.match?(HAS_ONE_ERROR_REGEX)
        parsed_key = @key.match(HAS_ONE_ERROR_REGEX)

        association_name = parsed_key[1].to_sym
        association_invalid_column = parsed_key[2].to_sym

        parse_error_message_for_has_one(association_name, association_invalid_column)

      else
        parse_error_message_for_base
      end

      @nested_error_messages
    end

    private

    def parse_error_message_for_nested(nested_resources_and_indexes, association_invalid_column)
      record = @base_model
      group_by_key = ''
      i = 1

      nested_resources_and_indexes.each do |association_name, association_index|
        record = record.send(association_name.to_sym)[association_index.to_i]
        group_by_key += association_name
        group_by_key += '_' unless i == nested_resources_and_indexes.count
        i += 1
      end

      group_by = @nested_error_groupings[group_by_key.to_sym].call(record)

      @nested_error_messages[group_by] ||= []
      @nested_error_messages[group_by] +=
        @messages.map { |message| @base_model.errors.full_message(association_invalid_column, message) }
    end

    def parse_error_message_for_has_one(association_name, association_invalid_column)
      # Call the lambda method to determine the grouping
      group_by = @nested_error_groupings[association_name].call

      @nested_error_messages[group_by] ||= []
      @nested_error_messages[group_by] +=
        @messages.map { |message| @base_model.errors.full_message(association_invalid_column, message) }
    end

    def parse_error_message_for_base
      base_model_grouping = @nested_error_groupings[@base_model.class.name.demodulize.underscore.to_sym]

      group_by =
        if base_model_grouping.present?
          base_model_grouping.call
        else
          @base_model.class.name.humanize
        end

      @nested_error_messages[group_by] ||= []
      @nested_error_messages[group_by] +=
        @messages.map { |message| @base_model.errors.full_message(@key, message) }
    end
  end
end
