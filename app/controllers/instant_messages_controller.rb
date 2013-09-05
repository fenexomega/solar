class InstantMessagesController < ApplicationController

  require 'xmpp/xmpp_client'

  def register_user
    unless current_user.im_register
      @xmpp_client = XmppClient.new(current_user.username)
      @xmpp_client.register(current_user.username)
      @xmpp_client.close

      current_user.im_register = true
      current_user.save
    end
    render json: {success: true}
  rescue
    render json: {success: false}, status: :unprocessable_entity
  end

  def login_user
    
    
    render json: {success: true}
  rescue
    render json: {success: false}, status: :unprocessable_entity
  end

  def logout_user
    @xmpp_client.close #(@xmpp_client)

    render json: {success: true}
  rescue Exception => error
    raise "#{error}"
   render json: {success: false}, status: :unprocessable_entity
  end

  def change_status
    if current_user.im_register
      @xmpp_client.change_status(params[:status].to_sym)
    end
    render json: {success: true}
  rescue Exception => error
    raise "#{error}"
    render json: {success: false}, status: :unprocessable_entity
  end



end
