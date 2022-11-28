class Badge
  RED = '#e05d44'.freeze
  GREEN = '#4c1'.freeze

  def initialize(type, results)
    @type = 'unknown'
    return if results.blank?

    # Ratio of the successful to all results
    @ratio = results.count { |r| r.code == 'succeeded' }.quo(results.length)
    @type = type == 'percent' ? 'percent' : status(results)
  end

  def xml
    file = Rails.public_path.join("badge-#{@type}.svg").read
    file = process_percent(file) if @type == 'percent'
    file
  end

  private

  def status(results)
    return 'failed' if results.any? { |r| r.code == 'failed' }

    'succeeded' if results.all? { |r| r.code == 'succeeded' }
  end

  def process_percent(file)
    file.gsub!(RED, GREEN) if @ratio == 1
    file.gsub('%PERCENTAGE%', "#{(@ratio * 100).to_i}%")
  end
end
