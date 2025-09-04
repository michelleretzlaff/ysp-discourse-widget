# name: ysp-discourse-widget
# about: Issues a short-lived JWT for the chat widget using the WordPress user id
# version: 0.1
# authors: You
# required_version: 3.0.0

enabled_site_setting :chat_widget_jwt_secret
enabled_site_setting :chat_widget_tenant_id

after_initialize do
  module ::ChatWidgetJwt
    class Engine < ::Rails::Engine
      engine_name "chat_widget_jwt"
      isolate_namespace ChatWidgetJwt
    end
  end

  ChatWidgetJwt::Engine.routes.draw do
    get "/token" => "token#show"
  end

  Discourse::Application.routes.append do
    mount ::ChatWidgetJwt::Engine, at: "/chat-widget"
  end

  class ChatWidgetJwt::TokenController < ::ApplicationController
    requires_login

    def show
      guardian.ensure_admin!

      secret = SiteSetting.chat_widget_jwt_secret
      raise Discourse::InvalidParameters.new(:chat_widget_jwt_secret) if secret.blank?

      user = current_user

      # Prefer DiscourseConnect (SSO) external_id (usually the WordPress user ID)
      wp_user_id =
        user.single_sign_on_record&.external_id ||
        user.custom_fields["wp_user_id"] ||
        user.id.to_s

      payload = {
        user_id:   wp_user_id.to_i,
        tenant_id: SiteSetting.chat_widget_tenant_id.to_i,
        email:     user.email,
        iat:       Time.now.to_i,
        exp:       (Time.now + 1.hour).to_i
      }

      token = JWT.encode(payload, secret, "HS256")
      render json: { token: token }
    end
  end
end
