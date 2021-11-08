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
        flash.clear
        @packageCheckUpgrade = PackageCheckUpgrade.new(packageCheckUpgrade_params)
        authorize @packageCheckUpgrade, :create?

        #Get action
        @create_action = params[:commit] == 'Create' ? true : false

        #Execute check
        result = execute_check(@packageCheckUpgrade)
        #Set state
        set_state(@packageCheckUpgrade)

        #Respond
        respond_to do |format|
            if @packageCheckUpgrade.state == 'error' or (@create_action and !@packageCheckUpgrade.save)
              format.js { flash.now[:error] = 'An error has occurred' }
            else
              if @create_action
                format.js { flash[:success] = 'Check upgrade saved successfully' }
              else
                format.js {}
              end
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
        
        if result.present?
          packageCheckUpgrade.output = result.gsub("\n", "\\n")
        else
          packageCheckUpgrade.output = nil
        end

        return result
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
