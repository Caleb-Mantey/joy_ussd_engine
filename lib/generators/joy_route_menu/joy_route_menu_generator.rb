class JoyRouteMenuGenerator < Rails::Generators::Base
  source_root File.expand_path('templates', __dir__)
  argument :menu_name, type: :string

  def generate_menu
    create_menu
  end

  private
  def create_menu
    template 'joy_route_menu_template.template', "app/services/ussd/menus/#{menu_name.underscore}_menu.rb"
  end
end
