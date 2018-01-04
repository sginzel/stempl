require 'gtk3'
#' Purpose of this module is to have a unified way to read files from a provided location
#' Remote locations are downloaded into a temporary directory
module Stempl
	module GuiForm
		class Base
			def initialize(varhash)
				@variables = varhash.dup
				@result = {}
			end
			
		end
		
		class MyGtk3 < Base
			
			def get_values_from_dialog(unset = false)
				return false if @inputs.nil?
				if (unset)
					@result = {}
					return true
				end
				@inputs.each do |name, input|
					if (input.is_a?(Gtk::Entry)) then
						@result[name] = input.text
					elsif (input.is_a?(Gtk::Button)) then
						@result[name] = input.instance_variable_get('@_my_value')
					elsif (input.is_a?(Gtk::ComboBoxText)) then
						@result[name] = input.instance_variable_get('@_my_value')
					end
					# puts "#{name} => #{@result[name]}"
				end
				true
			end
			
			def get
				@inputs = {}
				@result = {}
				@exit = false
				@window = Gtk::Window.new(Gtk::WindowType::TOPLEVEL)
				@window.set_title  'STEMPL Form'
				@window.border_width = 10
				@window.signal_connect('delete_event') { quit_main_gtk_loop }
				@keypress_handle = Proc.new {|win, evnt|
					if evnt.keyval == 65293 then # enter key
						get_values_from_dialog
						quit_main_gtk_loop
					end
					if evnt.keyval == 65307 then # escape key
						@exit = true
						#get_values_from_dialog(true) # remove all results
						quit_main_gtk_loop
					end
				}
				#@window.signal_connect('key_release_event') {|win,evnt|
				#	@keypress_handle.call(win, evnt)
				#}
				@hboxes = @variables.map{|name,defaul_val|
					create_hbox(name, defaul_val)
				}
				# make sure the first focusable element is focused
				i = @inputs.keys.select{|i| (!@inputs[i].nil?) && @inputs[i].can_focus?}.first
				@inputs[i].grab_focus unless i.nil?
				
				vbox = Gtk::Box.new(:vertical, 0)
				@hboxes.each do |hbox|
					vbox.pack_start(hbox)
				end
				
				button_ok = Gtk::Button.new(label: 'OK')
				button_ok.signal_connect('clicked') {
					get_values_from_dialog
					quit_main_gtk_loop
				}
				button_cancel = Gtk::Button.new(label: 'Cancel')
				button_cancel.signal_connect('clicked') {
					@exit = true
					# get_values_from_dialog(true)
					quit_main_gtk_loop
				}
				button_box = Gtk::Box.new(:horizontal, 2)
				button_box.pack_start(button_ok)
				button_box.pack_start(button_cancel)
				vbox.pack_start(button_box)
				
				@window.add(vbox)
				@window.show_all
				clear_event_queue
				Gtk.main
#				# clear main loop from pending events...
				clear_event_queue
				@window.hide
				@window.destroy
				exit 0 if @exit
				return @result
			end
			
			# we need to clear the event queue before quitting the main loop.
			# Mostly because there are events pending after key-released
			def quit_main_gtk_loop
				clear_event_queue
				Gtk.main_quit
			end
			
			def clear_event_queue
				while (Gtk.events_pending?) do
					Gtk.main_iteration
				end
			end
			
			def create_hbox(name, value)
				label = Gtk::Label.new(name.to_s)
				if value.is_a?(String) or value.is_a?(Symbol) then
					if value == "select_file" or value == :select_file then
						input = Gtk::Button.new(label: 'Choose file')
						input.signal_connect('clicked') {
							diag = Gtk::FileChooserDialog.new :title => 'Select File',
															  :parent => @window,
															  :action => Gtk::FileChooserAction::OPEN,
															  :buttons => [[Gtk::Stock::CANCEL, Gtk::ResponseType::CANCEL], [Gtk::Stock::OPEN, Gtk::ResponseType::ACCEPT]]
							if diag.run == Gtk::ResponseType::ACCEPT
								input.instance_variable_set('@_my_value', diag.filename)
							end
							diag.destroy
						}
					elsif value == "select_dir" or value == :select_dir then
						input = Gtk::Button.new(label: 'Choose directory')
						input.signal_connect('clicked') {
							diag = Gtk::FileChooserDialog.new :title => 'Select Folder',
															  :parent => @window,
															  :action => Gtk::FileChooserAction::SELECT_FOLDER,
															  :buttons => [[Gtk::Stock::CANCEL, Gtk::ResponseType::CANCEL], [Gtk::Stock::OPEN, Gtk::ResponseType::ACCEPT]]
							if diag.run == Gtk::ResponseType::ACCEPT
								input.instance_variable_set('@_my_value', diag.filename)
							end
							diag.destroy
						}
					else
						input = Gtk::Entry.new
						input.set_text(value.to_s)
						input.select_region(0, -1)
					end
				elsif value.is_a?(Fixnum) then
					input = Gtk::Entry.new
					input.set_text(value.to_s)
					input.select_region(0, -1)
				elsif value.is_a?(Float) then
					input = Gtk::Entry.new
					input.set_text(value.to_s)
					input.select_region(0, -1)
				elsif value.is_a?(Array) then
					cb = Gtk::ComboBoxText.new
					cb.signal_connect 'changed' do |w, e|
						cb.instance_variable_set('@_my_value', cb.active_text)
					end
					# make sure an empty record is avaiable
					if !value.any?{|x| x == ""} then
						cb.append_text("")
					end
					value.each do |v|
						cb.append_text(v.to_s)
					end
					input = cb
				else
					input = Gtk::Entry.new
					input.set_text(value.to_s)
					input.select_region(0, -1)
				end
				
				input.signal_connect('key_press_event') {|win,evnt|
					@keypress_handle.call(win, evnt)
				}
				
				@inputs[name] = input
				hbox = Gtk::Box.new(:horizontal, 2)
				hbox.pack_start(label)
				hbox.pack_start(input)
				hbox
			end
		end
	end
end
