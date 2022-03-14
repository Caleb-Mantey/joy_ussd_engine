require 'will_paginate/array'
module JoyUssdEngine
    class PaginateMenu < JoyUssdEngine::Menu
        # NOTE THIS CLASS SHOULD NEVER BE USED DIRECTLY BUT RATHER BE TREATED AS AN ABSTRACT CLASS
        # FROM WHICH OTHER CLASSES CAN INHERIT FROM AND IMPLEMENT CERTAIN CUSTOM BEHAVIOURS PERTAINING TO THEIR OPERATION

        # Paginating Menus will need to set entire collection in paginating_items, 
        # The current_page is automatically determined from the user input and 
        # the default values items_per_page, back_key, and next_key can be overiding in any class that inherits from the PaginatingMenu 
        # Every paginating menu must set the current_client_state property to be their client_state this keeps track of pagination and menu location

        # To paginate a menu you just call the `paginate` method and to display a paginated menu you call the `show_menu` method and pass the values returned from the `paginate` method. 
        # To get a item the user selects from the menu just use the `get_selected_item` method
        # EXAMPLE: 
        # my_items = paginate
        # show_menu(my_items)
        # selected_item = get_selected_item
        
        attr_reader :paginating_items, :paginating_items_selector, :paginating_error, :current_page, :items_per_page, :back_key, :next_key 

        def initialize(context)
            super(context)
            @items_per_page = 5
            @back_key = '0'
            @next_key = '#'
        end

        def paginate 

            before_paginate
            return [] if @paginating_error
            
            @current_page = get_current_page
            
            paginated_items = @paginating_items.to_a.paginate(page: @current_page, per_page: @items_per_page)

            is_first_render = @context.get_state[:"#{@field_name}_paginate_initiation"].blank?

            @context.set_state({"#{@field_name}_paginate".to_sym => @current_page, "#{@field_name}_paginated_list_size".to_sym => paginated_items.length, "#{@field_name}_list_size".to_sym => paginated_items.length, "#{@field_name}_paginate_initiation".to_sym => is_first_render ? "is_new" : "exists"})

            paginated_items
        end

        def show_menu(items=[], title = '')

            return if has_selected?
            
            @errors = true if @paginating_error || items.blank?
            return @error_text if @paginating_error
            return raise_error("Sorry something went wrong!") if items.blank?

            more_menu = !is_last_page(@current_page, items.length)
            back_menu = !is_first_page(@current_page) 

            item_number = (@current_page - 1) * @items_per_page

            tmp_menu = []
            
            first_option = item_number
            items.each do |m|
              tmp_menu << "#{first_option+=1}. #{m}"
            end

            tmp_menu << "#{back_key}. Back" if back_menu
            tmp_menu << "#{next_key}. Next" if more_menu
            text = tmp_menu.join("\n")
            text = "#{title}\n#{text}" unless title.blank?
            text
        end

        def has_selected?
            can_paginate? &&  ((@context.params[:message] != @next_key) && (@context.params[:message] != @back_key))
        end

        def can_paginate?
            @context.get_state[:"#{@field_name}_paginate_initiation"] == 'exists'
        end

        def can_load_more?
            !@context.get_state[:"#{@field_name}_paginate"].blank? &&
            (@context.params[:message] == @next_key) && !is_last_page(get_previous_page, @context.get_state[:"#{@field_name}_paginated_list_size"])
        end

        def can_go_back?
            !@context.get_state[:"#{@field_name}_paginate"].blank? &&
            (@context.params[:message] == @back_key) && !is_first_page(get_previous_page)
        end

        def get_selected_item(error_message = "Sorry wrong option selected")

            selected_item = nil
            check_input = is_numeric(@context.params[:message]) && @context.params[:message].to_i != 0
            if check_input 
                selected_item = @paginating_items_selector.blank? ? @paginating_items[@context.params[:message].to_i - 1] : @paginating_items_selector[@context.params[:message].to_i - 1]
            end
            

            @paginating_error = selected_item.blank?
            @error_text = error_message if @paginating_error
            selected_item
        end

        def load_next_page
            (@context.get_state[:"#{@field_name}_paginate"].to_i + 1)
        end

        def load_prev_page
            (@context.get_state[:"#{@field_name}_paginate"].to_i - 1)
        end

        def get_previous_page
            can_paginate? ? @context.get_state[:"#{@field_name}_paginate"] : 1
        end

        def get_current_page
            return 1 unless !@context.get_state[:"#{@field_name}_paginate"].blank?
            return load_prev_page if can_go_back?
            return load_next_page if can_load_more?
            @current_page
        end

        def check_input_errors?
           @errors = (!can_load_more? && @context.params[:message] == @next_key) || (!can_go_back? && @context.params[:message] == @back_key)

           @error_text = "Sorry invalid input" if @errors
           @errors
        end

        def is_last_page(page_number, page_items_size)
            (((page_number - 1) * 5) + page_items_size) >= @paginating_items.count
        end

        def is_first_page(page_number)
            page_number.present? ? page_number == 1 : true
        end

        def before_paginate
           @paginating_error = check_input_errors?
        end

        def before_render
            # To use pagination in a particular menu we need to follow the other of execution in the before_render method
            # 
            # 1. {my_items = paginate} - first you have to execute the `paginate` method and cache the value
            # 2. {show_menu(my_items)} - then you pass the cached value returned from the `paginate` method 
            # and save in some data in some variable you will use in the `render` method to render the page.
            # 3. {get_selected_item if has_selected?} - we use this to `get_selected_item` to return the item
            # the user selected and we do so by checking if the user has selected an item with the `has_selected?` method
        end

        def render
            # Paginating menu's render method calls the `load_menu` method to load a particular menu
            # This can come from a selected paginating item
            # load_menu(menu_name)

            # Paginating menus also terminates the session with a `joy_release` method to end the ussd_application
            # joy_release(@error_message - optional)
        end
        
        def execute
            save_field_value
            do_validation
            before_render
            return render_error[:data] if @paginating_error || @menu_error
            if !is_last_menu
                return render_previous if @previous_menu.field_error
            end
            response = render
            response = response.blank? ? joy_response(@current_client_state) : response
            after_render
            save_state(response[:ClientState]) if response[:ClientState] != "EndJoyUssdEngineiuewhjsdj"
            @context.reset_state if response[:ClientState] == "EndJoyUssdEngineiuewhjsdj" 
            response[:data].blank? ? response : response[:data]
        end
    end
end