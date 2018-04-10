# frozen_string_literal: true
xml.status do
  @result.each do |repo, archs|
    xml.repository(name: repo) do
      archs.each do |name, result, missing|
        if missing.blank?
          xml.arch(arch: name, result: result)
        else
          xml.arch(arch: name, result: result, missing: missing)
        end
      end
    end
  end
end
