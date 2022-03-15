# frozen_string_literal: true

require_relative "joy_ussd_engine/version"
require 'joy_ussd_engine/menu'
require 'joy_ussd_engine/paginate_menu'
require 'joy_ussd_engine/data_transformer'
require 'joy_ussd_engine/session_manager'


module JoyUssdEngine
  class Error < StandardError; end
  class Core
        include JoyUssdEngine::SessionManager
        
        attr_reader :params, :selected_provider
        attr_accessor :current_menu, :last_menu

        def initialize(params, provider, start_point: nil, end_point: nil )

            # gets provider currently in use and convert params to match ussd engines params
            @selected_provider =  provider.new(self)
            convert_params =  @selected_provider.send("request_params",params)
            @params = convert_params
            @last_menu = end_point.to_s
            @data = get_state
            # handles ending or terminating ussd based on provider response (HUBTEL, TWILIO, ETC.)
            # If a particular provider returns some sort of response that can terminate the app we do that check here
            return @current_menu = end_point.to_s if @selected_provider.send("app_terminator", params) || @data[:ClientState] == 'EndJoyUssdEngineiuewhjsdj'
            
            @current_menu = @data[:ClientState].blank? ? start_point.to_s : @data[:ClientState]
        end

        def load_menu(name)
            menu_name =  name.constantize.new(self) 
            menu_name.send("execute")
        end

        def load_from_paginate_menu(name)
          menu_name =  name.constantize.new(self) 
          menu_name.send("run")
        end

        def process
            load_menu(@current_menu)
        end
  end
end
