module Webui
  module Requests
    class CheckupgradeController < Webui::RequestController
      
      before_action :require_login
      before_action :set_package
      before_action :set_project

      #FIXME add "only" scope 
      after_action :verify_authorized 


      def update
      end

      def edit
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
          #Re-execute the check because the user could change something before the
          #submit
          result = execute_check(@packageCheckUpgrade)
          if result.present?
            @packageCheckUpgrade.output = result.gsub("\n", "\\n")
          end
          set_state(@packageCheckUpgrade)
          if @packageCheckUpgrade.state == 'error' or !@packageCheckUpgrade.save
            flash[:error] = 'An internal error has occurred'
          else
            flash[:success] = 'Check upgrade saved successfully'
          end
        end
        
      end

      def packageCheckUpgrade_params
        params.require(:packageCheckUpgrade).permit(:id, :package_id, :urlsrc, :regexurl, :regexver, :currentver, 
            :separator, :output, :state
          )
      end

      def execute_check(packageCheckUpgrade)
        result = packageCheckUpgrade.run_checkupgrade(packageCheckUpgrade.urlsrc, packageCheckUpgrade.regexurl, 
                                                      packageCheckUpgrade.regexver, packageCheckUpgrade.currentver, 
                                                      packageCheckUpgrade.separator, 'false', User.session.login)
        return result
      end

      def run_check(packageCheckUpgrade)
        
        flash.clear
        result = execute_check(packageCheckUpgrade)
        #If result is present, replace new line character
        if result.present?
          packageCheckUpgrade.output = result.gsub("\n", "\\n")
        else
          packageCheckUpgrade.output = nil
        end

        #Set state
        set_state(packageCheckUpgrade)

        #Respond
        check_upgrade_respond(packageCheckUpgrade)

      end

      def check_upgrade_respond(packageCheckUpgrade)
        respond_to do |format|
            format.json { render json: packageCheckUpgrade }
            if packageCheckUpgrade.state == 'error'
              format.js { flash.now[:error] = 'An internal error has occurred' }
            elsif 
              format.js {}
            end
        end
      end

      def set_state(packageCheckUpgrade)
        
        #Setting the state
        if ! packageCheckUpgrade.output.present? 
          packageCheckUpgrade.state = 'error'
        else
          if packageCheckUpgrade.output.start_with?('Error:')
            packageCheckUpgrade.state = 'error'
          elsif packageCheckUpgrade.output.start_with?('Available')
            packageCheckUpgrade.state = 'upgrade'
          elsif packageCheckUpgrade.output.start_with?('The package')
            packageCheckUpgrade.state = 'uptodate'
          end
        end 

      end

    end
  end
end
