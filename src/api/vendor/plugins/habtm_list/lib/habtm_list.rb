module RailsExtensions
  module HabtmList
  
    def self.append_features(base) #:nodoc:
      super
      base.extend(ClassMethods)
      base.class_eval do
        class << self
          alias_method :has_and_belongs_to_many_without_list_handling, :has_and_belongs_to_many
          alias_method :has_and_belongs_to_many, :has_and_belongs_to_many_with_list_handling
        end
      end
    end

    module ClassMethods
      def has_and_belongs_to_many_with_list_handling(name, options={}, &extension)
        if options.delete(:list)
          options[:extend] = RailsExtensions::HabtmList::AssociationListMethods

          after_add_callback_symbol = "maintain_list_after_add_for_#{name}".to_sym
          before_remove_callback_symbol = "maintain_list_before_remove_for_#{name}".to_sym
          
          options[:after_add] ||= []
          options[:after_add] << after_add_callback_symbol

          options[:before_remove] ||= []
          options[:before_remove] << before_remove_callback_symbol

          class_eval <<-EOV
            def #{after_add_callback_symbol}(added)
              self.#{name}.add_to_list_bottom(added)
            end
            
            def #{before_remove_callback_symbol}(removed)
              self.#{name}.remove_from_list(removed)
            end
          EOV
        end

        has_and_belongs_to_many_without_list_handling(name, options, &extension)
      end
    end
      
    module AssociationListMethods
      def move_to_position(item, position)
        return if !in_list?(item) || position.to_i == list_position(item)
        list_item_class.transaction do
          remove_from_list(item)
          insert_at_position(item, position)
        end
        resort_array
      end
  
      def move_lower(item)
        list_item_class.transaction do
          lower = lower_item(item)
          return unless lower
          decrement_position(lower)
          increment_position(item)
        end
        resort_array
      end
  
      def move_higher(item)
        list_item_class.transaction do
          higher = higher_item(item)
          return unless higher
          increment_position(higher)
          decrement_position(item)
        end
        resort_array
      end
  
      def move_to_bottom(item)
        return unless in_list?(item)
        list_item_class.transaction do
          decrement_positions_on_lower_items(item)
          assume_bottom_position(item)
        end
        resort_array
      end
  
      def move_to_top(item)
        return unless in_list?(item)
        list_item_class.transaction do
          increment_positions_on_higher_items(item)
          assume_top_position(item)
        end
        resort_array
      end

      # should only be called externally from the before_remove callback
      def remove_from_list(item)
        decrement_positions_on_lower_items(item) if in_list?(item)
        item[position_column] = nil
      end

      def first?(item)
        item == self.first
      end
  
      def last?(item)
        item == self.last
      end
  
      def higher_item(item)
        return nil unless in_list?(item)
        self.find(:first, :conditions => "#{position_column} = #{(list_position(item) - 1).to_s}")
      end

      def lower_item(item)
        return nil unless in_list?(item)
        self.find(:first, :conditions => "#{position_column} = #{(list_position(item) + 1).to_s}")
      end

      def in_list?(item)
        self.include?(item)
      end

      def add_to_list_bottom(item)
        item.save! if item.id.nil? # Rails 2.0.2 - Callbacks don't save first on association.create() 
        list_item_class.transaction do
          assume_bottom_position(item)
        end
        resort_array
      end
      
      def add_to_list_top(item)
        list_item_class.transaction do
          increment_positions_on_all_items
          assume_top_position(item)
        end
        resort_array
      end
      
      # "First aid" method in case someone shifts the array around outside these methods, or
      # the positions in the joins table go totally out of whack.  Don't use it for
      # simple ordering because it's inefficient.
      def reset_positions
        self.each_index do |i|
          item = self[i]
          connection.update(
            "UPDATE #{join_table} SET #{position_column} = #{i} " +
            "WHERE #{foreign_key} = #{@owner.id} AND #{list_item_foreign_key} = #{item.id}"
          )
        end
      end
          
      
  
      private
        def position_column
          @reflection.options[:order] || 'position'
        end
        
        def list_item_class
          @reflection.klass
        end
        
        def join_table
          @reflection.options[:join_table]
        end
        
        def foreign_key
          @reflection.primary_key_name
        end
        
        def list_item_foreign_key
          @reflection.association_foreign_key
        end
        
        def list_position(item)
          self.index(item)
        end


        def set_position(item, position)
          connection.update(
            "UPDATE #{join_table} SET #{position_column} = #{position} " +
            "WHERE #{foreign_key} = #{@owner.id} AND #{list_item_foreign_key} = #{item.id}"
          )
          if @target
            obj = @target.find {|obj| obj.id == item.id}
            obj[position_column] = position if obj
          end
        end

        def assume_bottom_position(item)
          set_position(item, self.length - 1)
        end

        def assume_top_position(item)
          set_position(item, 0)
        end

        def increment_position_by(item, increment)
          return unless in_list?(item)
          connection.update(
            "UPDATE #{join_table} SET #{position_column} = #{position_column} + (#{increment}) " +
            "WHERE #{foreign_key} = #{@owner.id} AND #{list_item_foreign_key} = #{item.id}"
          )
          if @target
            obj = @target.find {|obj| obj.id == item.id}
            obj[position_column] = obj[position_column].to_i + increment if obj
          end
        end

        def increment_position(item)
          increment_position_by(item, 1)
        end

        def decrement_position(item)
          increment_position_by(item, -1)
        end

        # This has the effect of moving all the higher items up one.
        def decrement_positions_on_higher_items(position)
          connection.update(
            "UPDATE #{join_table} SET #{position_column} = (#{position_column} - 1) " +
            "WHERE #{foreign_key} = #{@owner.id} AND #{position_column} <= #{position}"
          )
          @target.each { |obj|
            obj[position_column] = obj[position_column].to_i - 1 if in_list?(obj) && obj[position_column].to_i <= position
          } if @target
        end
    
        # This has the effect of moving all the lower items up one.
        def decrement_positions_on_lower_items(item)
          return unless in_list?(item)
          position = list_position(item)
          connection.update(
            "UPDATE #{join_table} SET #{position_column} = (#{position_column} - 1) " +
            "WHERE #{foreign_key} = #{@owner.id} AND #{position_column} > #{position}"
          )
          @target.each { |obj|
            obj[position_column] = obj[position_column].to_i - 1 if in_list?(obj) && obj[position_column].to_i > position
          } if @target
        end

        # This has the effect of moving all the higher items down one.
        def increment_positions_on_higher_items(item)
          return unless in_list?(item)
          position = list_position(item)
          connection.update(
            "UPDATE #{join_table} SET #{position_column} = (#{position_column} + 1) " +
            "WHERE #{foreign_key} = #{@owner.id} AND #{position_column} < #{position}"
          )
          @target.each { |obj|
            obj[position_column] = obj[position_column].to_i + 1 if in_list?(obj) && obj[position_column].to_i < position
          } if @target
        end

        # This has the effect of moving all the lower items down one.
        def increment_positions_on_lower_items(position)
          connection.update(
            "UPDATE #{join_table} SET #{position_column} = (#{position_column} + 1) " +
            "WHERE #{foreign_key} = #{@owner.id} AND #{position_column} >= #{position}"
          )
          @target.each { |obj|
            obj[position_column] = obj[position_column].to_i + 1 if in_list?(obj) && obj[position_column].to_i >= position
          } if @target
        end

        def increment_positions_on_all_items
          connection.update(
            "UPDATE #{join_table} SET #{position_column} = (#{position_column} + 1) " +
            "WHERE #{foreign_key} = #{@owner.id}"
          )
          @target.each { |obj|
            obj[position_column] = obj[position_column].to_i + 1 if in_list?(obj)
          } if @target
        end

        def insert_at_position(item, position)
          remove_from_list(item)
          increment_positions_on_lower_items(position)
          set_position(item, position)
        end
        
        # called after changing position values so the array reflects the updated ordering
        def resort_array
          @target.sort! {|x,y| x[position_column].to_i <=> y[position_column].to_i} if @target
        end      
    end
  end
end
