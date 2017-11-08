module PrettyNestedErrors
  class KeyAndMessagesParser
    DOUBLE_NESTED_ERROR_REGEX = /(\w+)\[(\d+)\]\.(\w+)\[(\d+)\]\.(\w+)/
    NESTED_ERROR_REGEX = /(\w+)\[(\d+)\]\.(\w+)/
    HAS_ONE_ERROR_REGEX = /(\w+)\.(\w+)/

    def initialize(base_model, key, messages, nested_error_messages, nested_error_groupings)
      @base_model = base_model
      @key = key
      @messages = messages
      @nested_error_messages = nested_error_messages
      @nested_error_groupings = nested_error_groupings
    end

    # This method hard codes the behaviour for validations errors on 4 different types of associations:
    # 1. errors on a double nested has_many association
    # 2. errors on a nested has_many association
    # 3. errors on a has_one associations
    # 4. errors on the base model
    # TODO: Make it so that the method uses regex to recursivley parse the validation key (i.e.
    # "package_groups[0].packages[0].name") so that it can handle n-level nested assoications
    def parse
      # Matches an error on a has_many nested resource of a has_many nested resource
      # like: {:"package_groups[0].packages[0].name"=>["can't be blank"]}
      if @key.match(DOUBLE_NESTED_ERROR_REGEX)
        parse_error_message_for_double_nested

      # Matches an error on a has_many nested resource
      # like {:"repositories[0].source_path"=>["can't be blank"]}
      elsif @key.match(NESTED_ERROR_REGEX)
        parse_error_message_for_nested

      # Matches an error on a has_one nested resource like: {:"preference.type_containerconfig_tag"=>["can't be blank"]}
      elsif @key.match(HAS_ONE_ERROR_REGEX)
        parse_error_message_for_has_one

      # Matches an error on the base resource like: {:"name"=>["can't be blank"]}
      else
        parse_error_message_for_base
      end

      @nested_error_messages
    end

    private

    def parse_error_message_for_double_nested
      parsed_key = @key.match(DOUBLE_NESTED_ERROR_REGEX)

      association_name = parsed_key[1].to_sym
      association_index = parsed_key[2].to_i
      sub_association_name = parsed_key[3].to_sym
      sub_association_index = parsed_key[4].to_i
      association_invalid_column = parsed_key[5]

      # Find the association record
      record = @base_model.send(association_name)[association_index].send(sub_association_name)[sub_association_index]

      # Call the lambda method to determine the grouping
      group_by = @nested_error_groupings["#{association_name}_#{sub_association_name}".to_sym].call(record)

      @nested_error_messages[group_by] ||= []
      @nested_error_messages[group_by] +=
        @messages.map { |message| @base_model.errors.full_message(association_invalid_column, message) }
    end

    def parse_error_message_for_nested
      parsed_key = @key.match(NESTED_ERROR_REGEX)

      association_name = parsed_key[1].to_sym
      association_index = parsed_key[2].to_i
      association_invalid_column = parsed_key[3]

      # Find the association record
      record = @base_model.send(association_name)[association_index]

      # Call the lambda method to determine the grouping
      group_by = @nested_error_groupings[association_name].call(record)

      @nested_error_messages[group_by] ||= []
      @nested_error_messages[group_by] +=
        @messages.map { |message| @base_model.errors.full_message(association_invalid_column, message) }
    end

    def parse_error_message_for_has_one
      parsed_key = @key.match(HAS_ONE_ERROR_REGEX)

      association_name = parsed_key[1].to_sym
      association_invalid_column = parsed_key[2].to_sym

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
