class InstantMessagesController < ApplicationController

  require 'xmpp/xmpp_client'

  def register_user
    unless current_user.im_register
      xmpp_client = XmppClient.new(current_user.username)
      xmpp_client.register(current_user.username)
      xmpp_client.close

      current_user.im_register = true
      current_user.save
    end

    render json: {success: true}
  rescue
    render json: {success: false}, status: :unprocessable_entity
  end

  def change_status

    render json: {msg: "mudou status novamente"}
  end

  def login_user
    if current_user.im_register
      @xmpp_client = XmppClient.login(current_user.username, current_user.username)
      puts "Controller #{@xmpp_client}"
      puts "#{@xmpp_client.class}"
      puts "#{@xmpp_client.client}"
      puts "#{@xmpp_client.client.class}"
    else
      register_user
      login_user
    end

   render json: {success: true}
  rescue
   render json: {success: false}, status: :unprocessable_entity

  end

    def logout_user
      if @xmpp_client
        @xmpp_client.close
      end
  render json: {success: true}
  rescue
   render json: {success: false}, status: :unprocessable_entity
  end

end
