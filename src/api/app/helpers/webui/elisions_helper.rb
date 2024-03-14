module Webui::ElisionsHelper
  # TODO: rename these methods. "elide" is a verb, something like "elision" and "combined_elision" could be better names.
  # This needs to replace them all over the code.

  # Shortens a text if it longer than 'length'.
  def elide(text, length = 20, mode = :middle)
    return '' if text.blank?

    return '...' if length <= 3 # corner case

    shortened_text = perform_elision(text, length, mode) if text.length > length
    shortened_text || text.to_s # making sure it's a String
  end

  def elide_two(text1, text2, overall_length = 40, mode = :middle)
    half_length = overall_length / 2
    text1_free = half_length - text1.to_s.length
    text1_free = 0 if text1_free.negative?
    text2_free = half_length - text2.to_s.length
    text2_free = 0 if text2_free.negative?
    [elide(text1, half_length + text2_free, mode), elide(text2, half_length + text1_free, mode)]
  end

  private

  def perform_elision(text, length, mode)
    case mode
    when :left # shorten at the beginning
      "...#{text[text.length - length + 3..text.length]}"
    when :middle # shorten in the middle
      pre = text[0..(length / 2) - 2]
      offset = 2 # depends if (shortened) length is even or odd
      offset = 1 if length.odd?
      post = text[text.length - (length / 2) + offset..text.length]
      "#{pre}...#{post}"
    when :right # shorten at the end
      "#{text[0..length - 4]}..."
    end
  end
end
