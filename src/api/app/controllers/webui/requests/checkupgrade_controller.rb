module Webui
  module Requests
    class CheckupgradeController < Webui::RequestController
      
      before_action :require_login
      before_action :set_package
      before_action :set_project

      #FIXME add "only" scope 
      after_action :verify_authorized 

      def update_table?(packageCheckUpgrade)
        
        @packageCheckUpgrade_db = PackageCheckUpgrade.find_by(id: packageCheckUpgrade.id)
        if ! @packageCheckUpgrade_db
          return false
        else
          if @packageCheckUpgrade_db.update(urlsrc: packageCheckUpgrade.urlsrc,
                                        regexurl: packageCheckUpgrade.regexurl,
                                        regexver: packageCheckUpgrade.regexver,
                                        currentver: packageCheckUpgrade.currentver,
                                        separator: packageCheckUpgrade.separator,
                                        output: packageCheckUpgrade.output,
                                        state: packageCheckUpgrade.state)
            return true
          else
            return false
          end
        end
      end

      def new
        @packageCheckUpgrade = PackageCheckUpgrade.find_by(package_id: @package.id)
        if ! @packageCheckUpgrade
          @packageCheckUpgrade = PackageCheckUpgrade.new
        end
        authorize @packageCheckUpgrade, :new?

        if @packageCheckUpgrade.state == 'error' 
          flash.now[:error] = 'An error has occurred'
        end

      end

      def create
        flash.clear

        #Get action
        @create_action = params[:commit] == 'Create' ? true : false
        @delete_action = params[:commit] == 'Delete' ? true : false
        @update_action = params[:commit] == 'Update' ? true : false

        if @delete_action
          @packageCheckUpgrade = PackageCheckUpgrade.find_by(id: params[:packageCheckUpgrade][:id])
        else
          @packageCheckUpgrade = PackageCheckUpgrade.new(packageCheckUpgrade_params)
        end
        authorize @packageCheckUpgrade, :create?

        #Skip these steps only for delete action
        if ! @delete_action
          #Execute check
          result = execute_check(@packageCheckUpgrade)
          #Set state
          set_state(@packageCheckUpgrade)
        end

        #Respond
        respond_to do |format|
          if @delete_action
            if !@packageCheckUpgrade.destroy  
              format.js { flash.now[:error] = 'An error has occurred' }
            else
              format.js { flash[:success] = 'Check upgrade deleted successfully' }
            end
          else
            if @packageCheckUpgrade.state == 'error' or 
              (@create_action and !@packageCheckUpgrade.save) or (@update_action and ! update_table?(@packageCheckUpgrade))
              format.js { flash.now[:error] = 'An error has occurred' }
            else
              if @create_action
                format.js { flash[:success] = 'Check upgrade saved successfully' }
              elsif @update_action
                format.js { flash[:success] = 'Check upgrade updated successfully' }
              end
            end    
          end
          format.js {}
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
