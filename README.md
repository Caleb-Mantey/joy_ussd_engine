# JoyUssdEngine

A ruby library for building text based applications rapidly. It supports building whatsapp, ussd, telegram and various text or chat applications that communicate with your rails backend. With this library you can target multiple platforms(whatsapp, ussd, telegram, etc.) at once with just one codebase.

## Table of Contents

- [JoyUssdEngine](#joyussdengine)
  - [Table of Contents](#table-of-contents)
  - [Installation](#installation)
  - [Usage](#usage)
    - [Bootstrap the App](#bootstrap-the-app)
    - [Generators](#generators)
    - [DataTransformer](#datatransformer)
      - [Methods](#methods)
      - [Example](#example)
    - [Menu](#menu)
      - [Menu Properties](#menu-properties)
      - [Lifecycle Methods](#lifecycle-methods)
      - [Render Methods](#render-methods)
      - [Other Methods](#other-methods)
      - [Create a menu](#create-a-menu)
      - [Execution Order of Lifecycle Methods](#execution-order-of-lifecycle-methods)
      - [Execution Order Diagram](#execution-order-diagram)
      - [Get Http Post Data](#get-http-post-data)
      - [Saving and Accessing Data](#saving-and-accessing-data)
      - [Error Handling](#error-handling)
    - [Routing Menus](#routing-menus)
    - [PaginateMenu](#paginatemenu)
      - [PaginateMenu Properties](#paginatemenu-properties)
      - [PaginateMenu Methods](#paginatemenu-methods)
      - [PaginateMenu Example](#paginatemenu-example)
  - [Transformer Configs](#transformer-configs)
    - [Hubtel Transformer](#hubtel-transformer)
    - [Twilio Transformer](#twilio-transformer)
  - [Development](#development)
  - [Contributing](#contributing)
  - [License](#license)
  - [Code of Conduct](#code-of-conduct)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'joy_ussd_engine'
```

And then execute:

    bundle install

Or install it yourself as:

    gem install joy_ussd_engine

## Usage

The ussd engine handles user session and stores user data with redis. So in your `Gemfile` you will have to add the `redis` and the `redis-namespace` gem.

```ruby
gem 'redis'
gem 'redis-namespace'

# Not required but you can add connection pool for redis if you want
gem 'connection_pool', '~> 2.2', '>= 2.2.2'
```

After installing redis you will need to setup the redis config in your rails application inside `config/initializers/redis.rb`

```ruby
# With Connection Pool
require 'connection_pool'
NAMESPACE = :DEFAULT_NAMESPACE
REDIS = ConnectionPool.new(size: 10) { Redis::Namespace.new(NAMESPACE, :redis => Redis.new) }
```

```ruby
# Without Connection Pool
NAMESPACE = :DEFAULT_NAMESPACE
REDIS = Redis::Namespace.new(NAMESPACE, :redis => Redis.new)
```

### Bootstrap the App

In your rails app inside a controller create a post route and initialize the `JoyUssdEngine` by calling `JoyUssdEngine::Core.new` and providing some parameters. [Click here](#params) to view all the required parameters list.

```ruby
class MyController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    joy_ussd_engine = JoyUssdEngine::Core.new(ussd_params, JoyUssdEngine::HubtelTransformer, start_point: Ussd::Menus::StartMenu, end_point: Ussd::Menus::EndMenu)
    response = joy_ussd_engine.process
    render json: response, status: :created
  end

  def ussd_params
    params.permit(:SessionId, :Mobile, :ServiceCode, :Type, :Message, :Operator, :Sequence, :ClientState)
  end
end
```

The `JoyUssdEngine::Core.new` class takes the following parameters.<a id="params"></a>

| Parameter                            | Type  | Description                                                                                                                          |
| ------------------------------------ | ----- | ------------------------------------------------------------------------------------------------------------------------------------ |
| params                               | hash  | Params coming from a post end point in a rails controller                                                                            |
| [data_transformer](#datatransformer) | class | A class to transform the incoming and outgoing request between a particular provider and `JoyUssdEngine`                             |
| [start_point](#menu)                 | class | Points to a menu that starts the application. This menu is the first menu that loads when the app starts                             |
| [end_point](#menu)                   | class | This menu will terminate the ussd session if a particular provider (`data_transformer`) returns true in the `app_terminator` method. |

### Generators

The rails terminal is very powerful and we can utilize it to generate menus easily.

- Generate a Menu - `rails g joy_menu <Menu_Name>`
- Generate a PaginateMenu - `rails g joy_paginate_menu <Menu_Name>`
- Generate a Routing Menu - `rails g joy_route_menu <Menu_Name>`
- Generate a DataTransformer - `rails g joy_data_transformer <Transformer_Name>`

### DataTransformer

A data transformer transforms the incoming request and outgoing response between a particular provider and the `JoyUssdEngine` so they can effectively communicate with each other. The `JoyUssdEngine` can accept any request object but there are two required fields that needs to be present for it to work properly. The required fields are `session_id` and `message`. This is why the `DataTransformer` is needed to convert the request so it can provide this two required fields (`session_id`, `message`).

#### Methods

| Method         | Parameters                                 | Return Value  | Description                                                                                                                                                                                             |
| -------------- | ------------------------------------------ | ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| request_params | params: [hash]()                           | [hash]()      | Converts the incoming request into a format the ussd engine can understand. The hash is the params coming from the post request in a rails controller that calls `JoyUssdEngine::Core.new`.             |
| response       | message: [string](), app_state: [string]() | [hash]()      | Converts the outgoing response coming from the ussd engine into a format the provider can understand. `(eg of providers: Whatsapp, Twilio, Hubtel, Telegram, etc.)`                                     |
| release        | message: [string]()                        | [hash]()      | Converts the outgoing response coming from the ussd engine into a format the provider can understand and then terminates the application. `(eg of providers: Whatsapp, Twilio, Hubtel, Telegram, etc.)` |
| app_terminator | params: [hash]()                           | [boolean]()   | Returns a true/false on whether to terminate the app when a particular condition is met based on the provider in use. `(eg of providers: Whatsapp, Twilio, Hubtel, Telegram, etc.)`                     |
| expiration     | none                                       | [Date/Time]() | Sets the time for which to end the user's session if there is no response from the user. **Default value is 60 seconds**                                                                                |

#### Example

When using `hubtel` we need to convert the `hubtel` request into what the `JoyUssdEngine` expects with the `request_params` method. Also we need to convert the response back from `JoyUssdEngine` to `hubtel` with the `response` and `release` methods. With this approach we can easily extend the `JoyUssdEngine` to target multiple providers like (Twilio, Telegram, etc) with ease. The `app_terminator` returns a boolean and terminates the app when a particular condition is met(For example: On whatsapp the user sends a message with text `end` to terminate the app)

```ruby
class Ussd::Transformers::HubtelTransformer < JoyUssdEngine::DataTransformer
    # Transforms request payload between hubtel and our application
    # The session_id and message fields are required so we get them from hubtel (session_id: params[:Mobile] and message: params[:Message]).
    # And we pass in other hubtel specific params like (ClientState: params[:ClientState], Type: params[:Type])
    def request_params(params)
        {
            session_id: params[:Mobile],
            message: params[:Message],
            ClientState: params[:ClientState],
            Type: params[:Type],
            data: params
        }
    end

    # We check if hubtel sends a params[:Type] == 'Release' and terminate the application
    # OR
    # the hubtel params[:Type] is not a string with value "Initiation" and state data is blank (@context.get_state.blank?)
    def app_terminator(params)
        params[:Type] == 'Release' || (params[:Type] != "Initiation" && @context.get_state.blank?)
    end

    # Transforms response payload back to the format hubtel accepts by setting the message field (Type: "Response",Message: message, ClientState: client_state)
    def response(message, client_state)
        {
            Type: "Response",
            Message: message,
            ClientState: client_state
        }
    end


    # Transforms response payload back to the format hubtel accepts by setting the message field (Type: "Response",Message: message, ClientState: client_state) and then end the user session
    def release(message)
        {
            Type: "Release",
            Message: message,
            ClientState: "End"
        }
    end


    # Time for which the session has to end if the user does not send a request.
    def expiration
        60.seconds
    end
end
```

### Menu

Menus are simply the views for our application. They contain the code for rendering the text that display on the user's device. Also they contain the business logic for your app.

#### Menu Properties

| Properties    | Type                                            | Description                                                                                                                             |
| ------------- | ----------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| @context      | object                                          | Provides methods for setting and getting state values                                                                                   |
| @field_name\* | string                                          | The name for a particular input field. This name can be used to later retrieve the value the user entered in that field. (**Required**) |
| @menu_text\*  | string                                          | The text to display to the user. (**Required**)                                                                                         |
| @error_text   | string                                          | If there is an error you will have to set the error message here. (**Optional**)                                                        |
| @skip_save    | boolean                                         | If set to true the user input will not be saved. **Default: false** (**Optional**)                                                      |
| @menu_items   | array <{title: '', route: JoyUssdEngine::Menu}> | Stores an array of menu items with their corresponding routes.                                                                          |
| @field_error  | boolean                                         | If set to true it will route back to the menu the error was caught in for the user to input the correct values.                         |

#### Lifecycle Methods

| Methods       | Description                                                                                                                                              |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| before_render | Do all data processing and business logic here.                                                                                                          |
| render        | Render the ussd menu here. This is for only rendering out the response. (Only these methods `joy_release`, `joy_response`, `load_menu` can be used here) |
| after_render  | After rendering out the ussd menu you can put any additional logic here.                                                                                 |
| on_validate   | Validate user input here.                                                                                                                                |
| on_error      | This method will be called when the `field_error` value is set to true. You can change the error message and render it to the user here.                 |

#### Render Methods

| Methods      | Parameters | Description                                                                                                                                                                                        |
| ------------ | ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| joy_response | Menu       | This method takes a single argument (which is a class that points to the next menu) and is used to render out the text stored in the `@menu_text` variable to the user.                            |
| joy_release  | none       | This method renders the text in the `@menu_text` variable to the user and ends the users session                                                                                                   |
| load_menu    | Menu       | This method takes a single argument (which is a class that points to the next menu) and is used with the [Routing](#routing-menus) and [Paginating](#paginatemenu) Menus to render out menu items. |

#### Other Methods

| Methods           | Description                                                                                                                             |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| show_menu         | Returns the menu text to be rendered out. This method is used with only [Routing](#routing-menus) and [Paginating](#paginatemenu) Menus |
| get_selected_item | Gets the users selection from the `@menu_items` array                                                                                   |
| raise_error       | Takes an error message as an arguments and renders the message to the user before ending the user's session                             |
| has_selected?     | Checks if the user has selected an item from the `@menu_items` array                                                                    |

#### Create a menu

```ruby
class Ussd::Menus::MainMenu < JoyUssdEngine::Menu
    def on_validate
        # use this method to validate the user's input

        # use @context.get_state with the @field_name value set in the before_render method to get the user inputs
        if @context.get_state[:request] != "john doe"
            # in case of errors set the @field_error value to true and set an error message in @error_text
            @field_error = true
            @error_text = "Wrong Value enter the correct value"
        end
    end

    def before_render
        # Implement before call backs

        # store the input name for this ussd menu in the @field_name variable
        @field_name = "request"

        # store the text to show or render out in the ussd menu with the @menu_text variable
        @menu_text = "Type you name"
    end

    def on_error
        # this method will be executed if @field_error is set to true

        # catch errors and display the errors in the ussd menu by setting the @menu_text to include the error_message from @error_text
        @menu_text = "#{@error_text}\n#{@menu_text}"
    end

    def after_render
        # Implement after call backs
    end

    def render
        # Render ussd menu here

        # the joy_response renders out the ussd menu and takes the class of the next menu to route to as an argument.
        joy_response(Ussd::Menus::NextMenu)
    end
end
```

This will be rendered out to the user when this menu is executed for the first time.

![Menu1](./images/menu_doc1.png)

When the user enters a value which is not the string `"john doe"` an error will be displayed like we see in the screenshot below.

![Menu2](./images/menu_doc2.png)

#### Execution Order of Lifecycle Methods

- before_render

  ***

  This is the first method that gets executed. It is used for querying the db and handling the business logic of our application. This method also is used to set the text (`@menu_text`) to be rendered and the input name (`@field_name`) for the current menu.

- on_error

  ***

  This is the next method that gets executed and it is used to set error messages. It will only be executed if the `@field_error` value is set to true.

- render

  ***

  This method is used for rendering out the menu by using the text stored in the `@menu_text` variable. There are only three methods that should be used in the render method. Which are [joy_release](#render-methods), [joy_response](#render-methods), and [load_menu](render-methods).

- after_render

  ***

  Use this method to do any other business logic after the menu has been rendered out and awaiting user response.

- on_validate

  ***

  This method will be executed when the user submits a response. We use this method to validate the user's input and set an error_message to display when there is an error. Normally we will set `@field_error` value to true and store the error message in `@error_text`. Then we can later access the error_message in the `on_error` lifecycle method and append the error message to `@menu_text` so it will be rendered out to the user.

#### Execution Order Diagram

The Diagram below shows how these methods are executed

![Lifecycle Diagram](images/lifecycle.jpg)

#### Get Http Post Data

We can access the post request data coming from the rails controller in any menu with the `@context` object. The `@context` object can be used to access post data by reading values from the `params` hash of a post request. This hash consist of the `session_id`, `message` and any other additional data returned by the `request_params` method in the [DataTransformer](#datatransformer) class.

```ruby
# Just call @context.params[key] to access a particular value coming from a post request made available to our app through the DataTransformer.request_params method.

@context.params[:message] # Gets the message the user enters from the post end point.
```

#### Saving and Accessing Data

We can save and access data in any menu with the `@context` object. The `@context` object has two methods `set_state` and `get_state` which are used for saving and retrieving data. The saved data will be destroyed once the user session ends or is expired and it is advisable to persist this data into a permanent storage like a database if you will need it after the user session has ended.

```ruby
# Just call @context.set_state(key: value) to set a key with a particular value
@context.set_state(selected_book: selected_book)

# To access the values @context.get_state[:key]
@context.get_state[:selected_book]
```

Also by default any menu that has the `@field_name` variable set. Will automatically save the users input with a key matching the string stored in the `@field_name` variable.

**Note:** However if the `@skip_save` variable is set to true the user input will not be store for that particular menu. By default this value is false.

```ruby
# This stores the name of the input field for this menu
@field_name = "user_email"

# @skip_save = true -  user input will not be saved

# We can now get the user's input any where in our application with @context.get_state.
@context.get_state[:user_email]
```

#### Error Handling

We can throw an error with a message and terminate the user session any where in our application by returning the `raise_error(error_message)` method and passing an error_message as an argument into the function.

```ruby
# We raise an error in our application
return raise_error("Sorry something went wrong!")
```

There is also another way to handle errors without ending or terminating the user session. We can use the `on_validate` lifecycle method to validate user input and when there is an error we set the `@field_error` variable to true and the `@error_text` variable to include the error message.

Then in the `on_error` lifecycle method we can append the `@error_text` variable to the `@menu_text` variable so it displays the error when render an output to the user.

**Note:** The `on_error` method will only be invoke if the `@field_error` variable is set to true.

[View the example code on error handling here](#create_menu)

### Routing Menus

You can show a list of menu items with their corresponding routes. When the user selects any item it will automatically route to the selected menu.
When the user selects a menu that is not in the list an error is displayed to the user and the user session wil be terminated.

```ruby
class Ussd::Menus::InitialMenu < JoyUssdEngine::Menu

    def before_render
        # Implement before call backs
        @field_name='initiation'
        @skip_save = true

        # Store a list of menu items with their routes
        @menu_items = [
            {title: 'Make Payments', route: Ussd::Menus::MakePayments},
            {title: 'View Transaction', route: Ussd::Menus::ViewTransaction}
        ]

        # Show menu items on screen with the show_menu method.
        # The show_menu takes an optional parameter which is used to display the title of the page.
        @menu_text = show_menu('Welcome to JoyUssdEngine')
    end

    def render
        # Render ussd menu here

        # Use the `load_menu` method to load the menus on screen
        # The `get_selected_item` method automatically listens to user inputs and passes the selected menu into the `load_menu` method
        load_menu(get_selected_item)
    end
end
```

This will be rendered out when this menu is executed

![MenuRoutes](./images/menu_items_routes.png)

If the `Ussd::Menus::ViewTransaction` has a structure like this.

```ruby
class Ussd::Menus::ViewTransaction < JoyUssdEngine::Menu

    def before_render
        # Implement before call backs

        @menu_text = "Transactions. \n1. ERN_CODE_SSD\n2. ERN_DESA_DAS\nThanks for using our services."
    end

    def render
        # Render ussd menu here
        joy_release
    end
end
```

When the user enters 2 in the `Ussd::Menus::InitialMenu` menu then the following will be rendered and the user session will be terminated.

![transaction](./images/transactions_menu.png)

The `Ussd::Menus::ViewTransaction` menu uses the `joy_release` method to render out the text stored in the `@menu_text` variable and ends the user session.

### PaginateMenu

A `PaginateMenu` handles pagination automatically for you. You can store an array of items that you want to paginate and they will be paginated automatically.
A `PaginateMenu` has all the properties and methods in a `Menu` in addition to the following properties.

#### PaginateMenu Properties

A `PaginateMenu` has the following properties in addition properties in [Menu](#menu).

| Properties        | Type        | Description                                                               |
| ----------------- | ----------- | ------------------------------------------------------------------------- |
| @paginating_items | array <any> | Stores an array of items to paginate on a particular menu.                |
| @items_per_page   | integer     | The number of items to show per page. **Default: 5**                      |
| @back_key         | string      | A string holding the input value for navigating back. **Default: '0'**    |
| @next_key         | string      | A string holding the input value for navigating forward. **Default: '#'** |

#### PaginateMenu Methods

| Methods           | Description                                                                                      |
| ----------------- | ------------------------------------------------------------------------------------------------ |
| paginate          | Returns a list of paginated items based on the page the user is currently on.                    |
| show_menu         | Takes a list of paginated items and a page title as a parameter and renders it out on the screen |
| get_selected_item | Returns the selected item                                                                        |
| has_selected?     | Returns true if the user has selected an item                                                    |

#### PaginateMenu Example

```ruby
 class Ussd::Menus::Books < JoyUssdEngine::PaginateMenu

        def before_render
            # Implement before call backs

            # set an array of items that are going to be paginated
            @paginating_items = [
                {title: "Data Structures", item: {id: 1}},
                {title: "Excel Programming", item: {id: 2}},
                {title: "Economics", item: {id: 3}},
                {title: "Big Bang", item: {id: 4}},
                {title: "Democracy Building", item: {id: 5}},
                {title: "Python for Data Scientist", item: {id: 6}},
                {title: "Money Mind", item: {id: 7}},
                {title: "Design Patterns In C#", item: {id: 8}}
            ]

            # The `paginate` method returns a list of paginated items for the current page when it is called
            paginated_list = paginate

            # In a PaginateMenu the `show_menu` method takes a list and two optional named parameter values (title,key).

            # The title shows the page title for the menu.

            # The key stores the key of the hash which contains the text to be rendered for each list item.

            # If the key is not set the paginating_items is treated as a string and rendered to the user.

            # eg: @paginating_items = ["Data Structures","Excel Programming","Economics","Big Bang","Democracy Building","Python for Data Scientist","Money Mind","Design Patterns In C#"]

            @menu_text = show_menu(paginated_list, title: 'My Books', key: 'title')

            # In other to select a paginating item we have to wrap the selection logic in an if has_selected? block to prevent some weird errors.
            if has_selected?
                # the get_selected_item is used to get the selected item from the paginating list
                selected_book = get_selected_item

                # We save the selected book so we can access later
                @context.set_state(selected_book: selected_book)
            end
        end

        def render
            # Render ussd menu here

            # The load_menu function points to a menu to load when a book is selected.
            load_menu(Ussd::Menus::ShowBook)
        end
    end
```

To use a `PaginateMenu` we have to store the items to be paginated in the `@paginating_items` variable. Then we call the `paginate` method and store the result in a variable (`paginated_list`). We can now pass the variable (`paginated_list`) into the `show_menu` method and specify a `title` for the page if we have any. The `show_menu` method can also accept a `key` which is used to get the key containing the string to be rendered in a paginating_item. If the `key` is left blank the `@paginating_items` are treated as strings and rendered automatically.

In order to get the item the user has selected we have to wrap the selection login in an `if has_selected?` block to prevent some weird errors, then we can access the selected item with the `get_selected_item` method.

The following screenshots shows the paginating menu when it's first rendered.

![paginate_menu1](./images/paginate_menu1.png)

When the user enters '#' we move to the next page in the list.

![paginate_menu2](./images/paginate_menu2.png)

In the next menu (`Ussd::Menus::ShowBook`) we have code that looks like this.

```ruby
class Ussd::Menus::ShowBook < JoyUssdEngine::Menu
    def before_render
        # Implement before call backs
        book = @context.get_state[:selected_book]
        @menu_text = "The selected book is \nid: #{book[:item][:id]}\nname: #{book[:title]}"
    end

    def after_render
        # Implement after call backs
    end

    def render
        # Render ussd menu here
        joy_release
    end
end
```

When th user selects an item in the `PaginateMenu` we get the users selection with `@context.get_state[:selected_book]` and display the selected item back to the user and end the session.

![paginate_item_select](images/paginate_item_selected.png)

## Transformer Configs

Transformer configs for various providers. This configs can be used if you use any of these providers.

### Hubtel Transformer

```ruby
class HubtelTransformer < JoyUssdEngine::DataTransformer
    # Tranforms request and response payload between hubtel and our application
    def request_params(params)
        {
            session_id: params[:Mobile],
            message: params[:Message],
            ClientState: params[:ClientState],
            Type: params[:Type]
            data: params
        }
    end

    def app_terminator(params)
        params[:Type] == 'Release' || (params[:Type] != "Initiation" && @context.get_state.blank?)
    end

    def response(message, client_state)
        {
            Type: "Response",
            Message: message,
            ClientState: client_state
        }
    end

    def release(message)
        {
            Type: "Release",
            Message: message,
            ClientState: "End"
        }
    end

    def expiration
        60.seconds
    end
end
```

### Twilio Transformer

```ruby
class TwilioTransformer < JoyUssdEngine::DataTransformer
    ACCOUNT_SID = "932843hwhjewhje7388"
    AUTH_TOKEN = "3473847hewjrejrheeee"

    def client
        @client ||= Twilio::REST::Client.new(ACCOUNT_SID, AUTH_TOKEN)
    end

    # Tranforms request and response payload between twilio and our application
    def request_params(params)
        {
            session_id: "0#{params[:From].last(9)}",
            message: params[:Body],
            Mobile: "0#{params[:From].last(9)}",
            data: params
        }
    end

    def app_terminator(params)
        params[:Body] == 'end'
    end

    def response(message, client_state)
        client.messages.create(
            from: from,
            to: to,
            body: message
        )
        {message: message}
    end

    def release(message)
        client.messages.create(
            from: from,
            to: to,
            body: message
        )
        {message: message}
    end

    def expiration
        # set expiration for different providers
    end

    def to
        "whatsapp:+233#{@context.params[:Mobile].last(9)}"
    end

    def from
        'whatsapp:+14155238886'
    end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at <https://github.com/Caleb-Mantey/joy_ussd_engine>. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/Caleb-Mantey/joy_ussd_engine/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the JoyUssdEngine project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/Caleb-Mantey/joy_ussd_engine/blob/master/CODE_OF_CONDUCT.md).
