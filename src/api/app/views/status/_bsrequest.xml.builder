# frozen_string_literal: true
xml.status(id: @id) do
  @result.each do |repo, archs|
    xml.repository(name: repo) do
      archs.each do |name, result|
        if result[:missing].blank?
          xml.arch(arch: name, result: result[:result])
        else
          xml.arch(arch: name, result: result[:result], missing: result[:missing])
        end
      end
    end
  end
end
