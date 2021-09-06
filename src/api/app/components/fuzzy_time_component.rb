# frozen_string_literal: true

class FuzzyTimeComponent < ApplicationComponent
  attr_reader :time

  def initialize(time:)
    super
    @time = time.utc
  end

  def human_time_ago
    return 'now' if (Time.now.utc - time) < 60

    "#{time_ago_in_words(time)} ago"
  end
end
