module Webui
  module Projects
    class RebuildTimesController < WebuiController
      before_action :require_login
      before_action :lockout_spiders, only: :show
      before_action :set_project, only: :show
      before_action :set_packages, only: :show

      def show
        logger.info("Statistics for RebuildTimesController#show: #{User.possibly_nobody.login}")
        @repository = params[:repository]
        @arch = params[:arch]
        @hosts = (params[:hosts] || 40).to_i
        @scheduler = params[:scheduler] || 'needed'
        unless %w[fifo lifo random btime needed neededb longest_data longested_triedread longest].include?(@scheduler)
          flash[:error] = 'Invalid scheduler type, check mkdiststats docu - aehm, source'
          redirect_to controller: '/webui/project', action: :show, project: @project
          return
        end
        bdep = Backend::Api::BuildResults::Binaries.builddepinfo(@project.name, @repository, @arch)
        jobs = Backend::Api::BuildResults::JobHistory.for_repository_and_arch(project_name: @project.name,
                                                                              repository_name: @repository,
                                                                              arch_name: @arch,
                                                                              filter: { limit: (@packages.size + @ipackages.size) * 3,
                                                                                        code: %w[succeeded unchanged] },
                                                                              raw: true)
        unless bdep && jobs
          flash[:error] = "Could not collect infos about repository #{@repository}/#{@arch}"
          redirect_to controller: '/webui/project', action: :show, project: @project
          return
        end
        longest = call_diststats(bdep, jobs)
        @longestpaths = []
        if longest
          longest['longestpath'].elements('path') do |path|
            currentpath = []
            path.elements('package') do |p|
              currentpath << p
            end
            @longestpaths << currentpath
          end
        end
        # we append 4 empty paths, so there are always at least 4 in the array
        # to simplify the view code
        4.times { @longestpaths << [] }
      end

      def rebuild_time_png
        key = params[:key]
        png = Rails.cache.read("rebuild-#{key}.png")
        headers['Content-Type'] = 'image/png'
        send_data(png, type: 'image/png', disposition: 'inline')
      end

      private

      def call_diststats(bdep, jobs)
        @timings = {}
        @pngkey = Digest::MD5.hexdigest(params.to_s)
        @rebuildtime = 0

        indir = Dir.mktmpdir
        File.write(File.join(indir, '_builddepinfo.xml'), bdep)
        File.write(File.join(indir, '_jobhistory.xml'), jobs)
        outdir = Dir.mktmpdir

        logger.debug "cd #{Rails.root.join('vendor/diststats')} && perl ./mkdiststats --srcdir=#{indir} --destdir=#{outdir}
                 --outfmt=xml #{@project.name}/#{@repository}/#{@arch} --width=910
                 --buildhosts=#{@hosts} --scheduler=#{@scheduler}"
        oldpwd = Dir.pwd
        Dir.chdir(Rails.root.join('vendor/diststats'))
        unless system('perl', './mkdiststats', "--srcdir=#{indir}", "--destdir=#{outdir}",
                      '--outfmt=xml', "#{@project.name}/#{@repository}/#{@arch}", '--width=910',
                      "--buildhosts=#{@hosts}", "--scheduler=#{@scheduler}")
          Dir.chdir(oldpwd)
          return
        end
        Dir.chdir(oldpwd)
        begin
          f = File.open("#{outdir}/rebuild.png")
          png = f.read
          f.close
        rescue StandardError
          return
        end
        Rails.cache.write("rebuild-#{@pngkey}.png", png)
        f = File.open("#{outdir}/longest.xml")
        longest = Xmlhash.parse(f.read)
        longest['timings'].elements('package') do |p|
          @timings[p['name']] = [p['buildtime'], p['finished']]
        end
        @rebuildtime = Integer(longest['rebuildtime'])
        f.close
        FileUtils.rm_rf(indir)
        FileUtils.rm_rf(outdir)
        longest
      end

      def set_packages
        @packages = []
        @project.packages.order_by_name.pluck(:name, :updated_at).each do |p|
          @packages << [p[0], p[1].to_i.to_s] # convert Time to epoch ts and then to string
        end
        @ipackages = @project.expand_all_packages.find_all { |ip| @packages.pluck(0).exclude?(ip[0]) }
      end
    end
  end
end
