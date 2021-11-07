module Webui
  module Requests
    class CheckupgradeController < Webui::RequestController
      
      before_action :require_login
      before_action :set_package
      before_action :set_project

      #FIXME add "only" scope 
      after_action :verify_authorized 


      def update
        print "Sono in update di CheckupgradeController"  
      end

      def edit
        print "Sono in edit di CheckupgradeController"
        @packageCheckUpgrade = PackageCheckUpgrade.find_by(id: params[:id])
        authorize @packageCheckUpgrade, :edit?
      end

      def new

        @packageCheckUpgrade = PackageCheckUpgrade.find_by(package_id: @package.id)
        if ! @packageCheckUpgrade
          @packageCheckUpgrade = PackageCheckUpgrade.new
        end
        authorize @packageCheckUpgrade, :new?
      end

      def create
        @packageCheckUpgrade = PackageCheckUpgrade.new(packageCheckUpgrade_params)
        authorize @packageCheckUpgrade, :create?

        @commit = params[:commit]
        if @commit == 'Run check'
          run_check(@packageCheckUpgrade)
        else
          if @packageCheckUpgrade.save
            #FIXME Redirect to package only if the state != error
            redirect_to package_show_path(@project, @package)
          else
            redirect_to new_project_package_checkupgrade_path(@project, @package)
          end
        end
        
      end

      def packageCheckUpgrade_params
        params.require(:packageCheckUpgrade).permit(:package_id, :urlsrc, :regexurl, :regexver, :currentver, 
            :separator, :output, :state
          )
      end

      def run_check(packageCheckUpgrade)
        result = packageCheckUpgrade.run_checkupgrade(packageCheckUpgrade.urlsrc, packageCheckUpgrade.regexurl, 
                                                      packageCheckUpgrade.regexver, packageCheckUpgrade.currentver, 
                                                      packageCheckUpgrade.separator, 'false', User.session.login)
        packageCheckUpgrade.output = result

        respond_to do |format|
            format.html { render action: "new" }
            format.js 
            format.json { render json: packageCheckUpgrade }
        end
      end

    end
  end
end
