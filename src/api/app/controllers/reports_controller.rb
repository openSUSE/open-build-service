class ReportsController < ApplicationController
  def index
    @reports = Report.order(:id)
    authorize @reports
  end

  # TODO
  # def create
  # end

  def show
    @report = Report.find(params[:id])
    authorize @report
  end

  def destroy
    report = Report.find(params[:id])
    authorize report

    report.destroy
    render_ok
  end

  # TODO
  # def update
  # end
end
