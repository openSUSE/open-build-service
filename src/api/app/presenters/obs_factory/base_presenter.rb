module ObsFactory
  # Extremely simple implementation of the Decorator pattern for the views.
  #
  # At some point, it would make sense to adopt Draper or any
  # other gem implementing more full-featured decorators.
  # https://github.com/drapergem/draper
  class BasePresenter < SimpleDelegator
    # Decorate a collection of objects
    #
    # @params [#map]  collection  objects to decorate
    # @return [Array] array of presenter objects
    def self.wrap(collection)
      collection.map do |obj|
        new obj
      end
    end

    # The original object
    #
    # @return [Object] object without decoration
    def model
      __getobj__
    end
  end
end
