

class Users::SessionsController < ApplicationController
  skip_before_filter :authenticate_conditionally, :only => [ :create, :new ]

  def new
    session[:return_url] = Rails.configuration.action_controller.relative_url_root
    redirect_to omniauth_path(:cas)
  end

  def create

    # extract authentication data
    auth = request.env["omniauth.auth"]
    logger.debug auth.extra.hashie_inspect
    provider = params['provider']
    username = auth.extra.user

    session[:user] = auth
    return_url = session.delete('return_url')
    #redirect_to return_url, :notice => I18n.t('dias.loggetind') +" " + auth.extra.gn + " " + auth.extra.sn + "" + I18n.t('dias.loggetindupklartilload'), :only_path => true
    redirect_to root_url, :notice => I18n.t('dias.loggetind') +" " + auth.extra.gn + " " + auth.extra.sn + "" + I18n.t('dias.loggetindupklartilload'), :only_path => true

  rescue Exception => e
    puts e.to_s + e.backtrace.join("\n")
  end

  def destroy
    reset_session
    redirect_to root_path
  end

  def omniauth_path(provider)
    "/auth/#{provider.to_s}"
  end

  def switch
    render(:file => 'public/401', :format => :html, :status => :unauthorized) and return unless can? :switch, User 
  end

  def update
    @is_ajax = params[:ajax]

    if can? :switch, User
      # new_user_id is made available for switch user form to be able
      # to populate the form with submitted data when there is an error
      @new_user_id = params[:user][:identifier]
      account = Dtubase::Account.find_by_cwis(@new_user_id) || Dtubase::Account.find_by_username(@new_user_id)

      if account == nil
        flash[:error] = 'User not found'
        if @is_ajax
          render :text => flash[:error], :status => 404 and return
        else
          redirect_to switch_user_path, flash: flash
          return
        end
      end

      new_user = User.create_or_update_with_account('cas', account)
      session[:original_user_id] = current_user.id
      session[:user_id] = new_user.id

      # Switching user affects abilities - in particular when switching
      # to a user that can also switch user, it should not be allowed
      # to switch further. Instead it should be allowed to switch back.
      # Otherwise we would need to keep a stack of the users, that was
      # switched into in order to get the proper "switch back" functionality
      # and that behaviour just seems silly.
      @current_ability = nil
      flash[:notice] = "You succesfully switched user."
      flash.keep :notice

    elsif can? :switch_back, User
      # Restore original user and his cancan abilities
      session[:user_id] = session[:original_user_id]
      session.delete :original_user_id
      
      @current_ability = nil
      flash[:notice] = "You succesfully switched user."
      flash.keep :notice

    else
      if @is_ajax
        head :forbidden and return
      else
        flash[:error] = 'Not allowed'
      end
    end

    if @is_ajax
      head :ok
    else
      redirect_to root_path
    end
  end


end
