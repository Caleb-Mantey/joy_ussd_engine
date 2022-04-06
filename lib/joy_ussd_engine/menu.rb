require 'will_paginate/array'
module JoyUssdEngine
    class Menu
        # THIS CLASS IS THE BASE CLASS FOR ALL MENUS IN THE USSD ENGINE. EVERY MENU INHERITS FROM THIS CLASS AND IMPLEMENT THEIR CUSTOM BEHAVIOURS.

        # NOTE THIS CLASS SHOULD NEVER BE USED DIRECTLY BUT RATHER BE TREATED AS AN ABSTRACT CLASS
        # FROM WHICH OTHER CLASSES CAN INHERIT FROM AND IMPLEMENT CERTAIN CUSTOM BEHAVIOURS PERTAINING TO THEIR OPERATION

        attr_reader :context
        attr_accessor :field_name, :field_error, :errors, :skip_save, :previous_client_state, :current_client_state, :menu_text, :error_text, :menu_items, :menu_error, :previous_menu

        def initialize(context)
            @context = context
            @current_client_state = @context.current_menu
        end

        def joy_response(client_state)
            new_state = client_state.to_s
            if @menu_text.blank?
                set_previous_state
                @context.current_menu = @current_client_state = new_state
                return @context.load_menu(new_state)
            end

            { 
                ClientState: new_state,
                data: @context.selected_provider.send("response", @menu_text, new_state) 
            }            
        end

        def joy_release(error_message = "")
            @context.reset_state
            { 
                ClientState: "EndJoyUssdEngine",
                data: @context.selected_provider.send("release", error_message.blank? ? @menu_text : error_message)
            }
        end

        def load_menu(menu_to_load)
            return render_menu_error[:data] if @menu_error
            next_menu = menu_to_load.to_s
            if has_selected?
                @context.set_state({"#{@current_client_state}_show_menu_initiation".to_sym =>  nil})
                set_previous_state 
                @context.current_menu = @current_client_state = next_menu
                @context.load_from_paginate_menu(next_menu) 
            end
        end

        def show_menu(title = '')
            raise_error("Sorry something went wrong!") if @menu_items.blank?
            tmp_menu = []
            
            first_option = 0
            @menu_items.each do |m|
              tmp_menu << "#{first_option+=1}. #{m[:title]}"
            end
            text = tmp_menu.join("\n")
            title.blank? ? text : "#{title}\n#{text}" 
        end

        def before_show_menu
            is_first_render = @context.get_state[:"#{@current_client_state}_show_menu_initiation"].blank?
            @context.set_state({"#{@current_client_state}_show_menu_initiation".to_sym => is_first_render ? "is_new" : "exists"})
        end

        def has_selected?
            @context.get_state[:"#{@current_client_state}_show_menu_initiation"] == "exists"
        end

        def get_selected_item(error_message = "Sorry wrong option selected")

            return unless has_selected?

            selected_item = nil
            check_input = is_numeric(@context.params[:message]) && @context.params[:message].to_i != 0  && !(@context.params[:message].to_i > @menu_items.length)

            if check_input 
                selected_item = @menu_items[@context.params[:message].to_i - 1][:route]
            end

            # 17332447
            
            @menu_error = selected_item.blank?
            @error_text = error_message if @menu_error

            selected_item
        end

        def is_numeric(numeric_string)
            "#{numeric_string}" !~ /\D/
        end

        def before_render
            # Implement before call backs
            puts "before render passed"
        end

        def after_render
            # Implement after call backs
            puts "after render passed"
        end

        def save_state(state)
            return if @skip_save
            data = @context.get_state
            @previous_client_state = @current_client_state
            # @context.set_state({"#{data[:field]}".to_sym => @context.params[:message]}) unless data[:field].blank?
            @context.set_state({ClientState: state, PrevClientState: @previous_client_state , field: @field_name, field_error: @field_error, error_text: @error_text})
        end

        def save_field_value
            data = get_previous_state
            return if @skip_save
            @context.set_state({"#{data[:field]}".to_sym => @context.params[:message]}) unless data[:field].blank?
        end

        def get_previous_state
            data = @context.get_state
            @previous_client_state = data[:PrevClientState]
            data
        end

        def set_previous_state
            @context.set_state({PrevClientState: @current_client_state})
        end

        def render
            # Render ussd menu here
            puts "render passed"
        end

        def on_validate
            
        end

        def on_error
            
        end

        def raise_error(message)
            @error_text = message
            @menu_error = true
        end

        def render_menu_error
            @context.reset_state
            joy_release(@error_text)
        end

        def render_field_error
            before_show_menu
            before_render
            on_error
            return render_menu_error[:data] if menu_error
            response = render
            response = response.blank? ? joy_response(current_client_state) : response
            after_render
            save_state(response[:ClientState]) if response[:ClientState] != "EndJoyUssdEngine"
            @context.reset_state if response[:ClientState] == "EndJoyUssdEngine" 
            response[:data].blank? ? response : response[:data]
        end

        def render_previous
           @context.current_menu = @previous_menu.current_client_state = @previous_client_state
           @context.set_state({"#{@previous_client_state}_show_menu_initiation".to_sym =>  nil})
           @previous_menu.render_field_error
        end

        def is_last_menu
            @context.last_menu == @current_client_state
        end

        def allow_validation
            !is_last_menu && !@previous_client_state.blank?
        end

        def do_validation
            return unless allow_validation
           @previous_menu = @previous_client_state.constantize.new(@context)
           @previous_menu.on_validate
        end

        def run
            save_field_value
            do_validation
            before_show_menu
            before_render
            return render_menu_error[:data] if @menu_error
            if allow_validation
                return render_previous if @previous_menu.field_error
            end
            response = render
            response = response.blank? ? joy_response(@current_client_state) : response
            after_render
            save_state(response[:ClientState]) if response[:ClientState] != "EndJoyUssdEngine"
            @context.reset_state if response[:ClientState] == "EndJoyUssdEngine" 
            response
        end

        def execute
            save_field_value
            do_validation
            before_show_menu
            before_render
            return render_menu_error[:data] if @menu_error
            if allow_validation
                return render_previous if @previous_menu.field_error
            end
            response = render
            response = response.blank? ? joy_response(@current_client_state) : response
            after_render
            save_state(response[:ClientState]) if response[:ClientState] != "EndJoyUssdEngine"
            @context.reset_state if response[:ClientState] == "EndJoyUssdEngine" 
            response[:data].blank? ? response : response[:data]
        end
    end
end