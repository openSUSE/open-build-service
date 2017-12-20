# Controller to manage dogs
class Webui::DogsController < ApplicationController
  #### Includes and extends
  include AnimalControl

  #### Constants
  BASIC_DOG_NAMES = %w(Tobby Thor Rambo Dog Blacky).freeze

  #### Self config

  #### Callbacks macros: before_action, after_action, etc.
  before_action :set_dog, only: [:show, :edit, :update, :destroy]
  # Pundit authorization policies control
  after_action :verify_authorized, except: [:index, :blacks]
  after_action :verify_policy_scoped, only: [:index, :blacks]

  #### CRUD actions

  # GET /dogs
  def index
    @dogs = policy_scope(Dog)
  end

  # GET /dogs/1
  def show
    if @dog.present?
      authorize @dog
    else
      skip_authorization
    end
  end

  # GET /dogs/new
  def new
    @dog = Dog.new
    authorize @dog
  end

  # GET /dogs/1/edit
  def edit
    authorize @dog
  end

  # POST /dogs
  def create
    @dog = Dog.new(dog_params)
    authorize @dog
    if @dog.save
      redirect_to @dog, notice: 'Dog was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /dogs/1
  def update
    authorize @dog
    if @dog.update(dog_params)
      redirect_to @dog, notice: 'Dog was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /dogs/1
  def destroy
    authorize @dog
    @dog.destroy
    redirect_to dogs_url, notice: 'Dog was successfully destroyed.'
  end

  #### Non CRUD actions

  # List all the black dogs
  # GET /dogs/blacks
  def blacks
    @dogs = policy_scope(Dog).blacks
    call_them(@dogs)
    render :index
  end

  #### Non actions methods
  # Use hide_action if they are not private

  def call_them(dogs = [])
    say('Hey!')
    dogs.each(&:bark)
  end

  hide_action :call_them

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_dog
    @dog = Dog.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def dog_params
    params.require(:dog).permit(:name, :color)
  end
end
