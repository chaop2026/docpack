module Admin
  class SessionsController < ApplicationController
    layout "admin"

    def new
    end

    def create
      if params[:password] == admin_password
        session[:admin_authenticated] = true
        redirect_to admin_banners_path, notice: "Logged in."
      else
        flash.now[:alert] = "Invalid password."
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      session.delete(:admin_authenticated)
      redirect_to admin_login_path, notice: "Logged out."
    end

    private

    def admin_password
      ENV.fetch("ADMIN_PASSWORD", "docpack2025")
    end
  end
end
