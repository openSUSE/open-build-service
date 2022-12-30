class Badge
  RED = '#e05d44'.freeze
  GREEN = '#4c1'.freeze
  FAILED = %w[failed unresolvable broken].freeze

  def initialize(type, states)
    @type = 'unknown'
    finalstates = states&.select { |r| ['succeeded', *FAILED].any?(r.code) }
    return if finalstates.blank?

    # Ratio of the successful to all results
    @ratio = finalstates.count { |r| r.code == 'succeeded' }.quo(finalstates.length)
    @type = type == 'percent' ? 'percent' : status(finalstates)
  end

  def xml
    file = Rails.public_path.join("badge-#{@type}.svg").read
    file = process_percent(file) if @type == 'percent'
    file
  end

  private

  def status(finalstates)
    return 'failed' if finalstates.any? { |r| FAILED.include?(r.code) }
    return 'succeeded' if finalstates.all? { |r| r.code == 'succeeded' }

    'unknown'
  end

  def process_percent(file)
    file.gsub!(RED, GREEN) if @ratio == 1
    file.gsub('%PERCENTAGE%', "#{(@ratio * 100).to_i}%")
  end
end
