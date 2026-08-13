# frozen_string_literal: true

require 'gtk3'



module MooTool
  module GUI
    class Application < Gtk::Application
      Gio::Resources.register(Gio::Resource.load(MooTool::GRESOURCE_BIN))

      def initialize
        super('me.rickmark.mootool', :handles_open)

        signal_connect 'startup' do |application|
          builder = Gtk::Builder.new(:resource => "/me/rickmark/mootool/app-menu.ui")
          app_menu = builder.get_object("appmenu")
          application.set_app_menu(app_menu)

          action = Gio::SimpleAction.new("quit")
          action.signal_connect("activate") do |_action, parameter|
            application.quit
          end
          application.add_action(action)
        end


        signal_connect 'activate' do |application|
          window = PrintWindow.new(application)
          window.present
        end

        signal_connect 'open' do |application, files, _hint|
          windows = application.windows

          win = if windows.empty?
                  PrintWindow.new(application)
                else
                  windows.first
                end

          win.open(files)

          win.present
        end


      end
    end
  end
end
