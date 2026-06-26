module Webui::ColorHelper
  # Calculates a text color that will contrast well with the given color
  def contrast_text(color)
    red_component = color[1..2].to_i(16)
    green_component = color[3..4].to_i(16)
    blue_component = color[5..6].to_i(16)

    red = relative_luminance(red_component / 255.0)
    green = relative_luminance(green_component / 255.0)
    blue = relative_luminance(blue_component / 255.0)

    # https://www.w3.org/TR/WCAG20/#contrast-ratiodef
    ((0.2126 * red) + (0.7152 * green) + (0.0722 * blue)) > 0.179 ? 'black' : 'white'
  end

  # https://www.w3.org/TR/WCAG20/#relativeluminancedef
  def relative_luminance(color)
    return color / 12.92 if color <= 0.03928

    ((color + 0.055) / 1.055)**2.4
  end
end
