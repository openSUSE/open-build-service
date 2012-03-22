
xml.instruct!

if @group_by_mode

  xml.download_counter( :all => @all, :first => @first, :last => @last ) do
    @stats.each do |stat|
      if @group_by_mode == 'package' or @group_by_mode == 'repo'
        xml.count(
          stat.counter_sum.to_s,
          @group_by_mode.to_sym => stat.obj_name,
          :files => stat.files_count,
          :project => stat.pro_name
        )
      else
        xml.count(
          stat.counter_sum.to_i,
          @group_by_mode.to_sym => stat.obj_name,
          :files => stat.files_count
        )
      end
    end
  end

else

  xml.download_counter( :all => @all, :sum => @sum.to_i, :first => @first, :last => @last ) do
    @stats.each do |stat|
      xml.count(
        stat.count.to_s,
        :project => stat.pro_name,
        :package => stat.pac_name,
        :repository => stat.repo_name,
        :architecture => stat.arch_name,
        :filename => stat.filename,
        :filetype => stat.filetype,
        :version => stat.version,
        :release => stat.release
      # :created_at => stat.created_at.xmlschema,
      # :counted_at => stat.counted_at.xmlschema,
      )
    end
  end

end
