class JoyPaginateMenuGenerator < Rails::Generators::Base
  source_root File.expand_path('templates', __dir__)
  argument :paginating_menu_name, type: :string

  def generate_menu
    create_menu
  end

  private
  def create_menu
    template 'joy_paginate_menu_template.template', "app/services/ussd/menus/#{paginating_menu_name.underscore}_menu.rb"
  end
end
