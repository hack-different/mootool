# frozen_string_literal: true

module MooTool
  module GUI
    class PrintWindow < Gtk::ApplicationWindow
      COLOR = {
        '1' => 'bold',
        '30' => 'black',
        '31' => 'red',
        '32' => 'green',
        '33' => '#9B870C',
        '34' => 'blue',
        '35' => '#008B8B',
        '36' => '#008B8B',
        '37' => 'black',
        '90' => 'grey'
      }.freeze

      UI_FILE = '/me/rickmark/mootool/print_window.ui'
      type_register

      # Tree store columns: name (String), node type (String), node id (String),
      # internal index into @tree_nodes for property lookup
      TREE_COL_NAME = 0
      TREE_COL_TYPE = 1
      TREE_COL_ID   = 2
      TREE_COL_IDX  = 3

      # Properties list store columns
      PROP_COL_KEY   = 0
      PROP_COL_VALUE = 1

      class << self
        def init
          set_template(resource: UI_FILE)
          bind_template_child('file_list')
          bind_template_child('content_tree')
          bind_template_child('properties_view')
        end
      end

      def initialize(application)
        super(application: application)

        @files = []
        @tree_nodes = []

        setup_tree_view
        setup_properties_view
        setup_file_list_selection
      end

      def present
        ensure_files
        super
      end

      def ensure_files
        return if @files.any?

        files = Models::FileIndex.current.index.map(&:fullname)
        open(files)
      end

      def open(files)
        @files = files.map { |file| file.is_a?(Gio::File) ? file.path : file.to_s }

        @files.each do |file|
          row = Gtk::ListBoxRow.new
          label = Gtk::Label.new(::File.basename(file))
          label.xalign = 0.0
          label.margin_start = 6
          label.margin_end = 6
          label.margin_top = 4
          label.margin_bottom = 4
          row.add(label)
          row.show_all
          file_list.add(row)
        end

        # Auto-select the first file added
        load_file(path) if @files.size == 1
      end

      private

      def setup_tree_view
        @tree_store = Gtk::TreeStore.new(String, String, String, Integer)
        content_tree.model = @tree_store

        renderer = Gtk::CellRendererText.new
        column = Gtk::TreeViewColumn.new('Node', renderer, markup: TREE_COL_NAME)
        column.resizable = true
        column.expand = true
        content_tree.append_column(column)

        type_renderer = Gtk::CellRendererText.new
        type_column = Gtk::TreeViewColumn.new('Type', type_renderer, markup: TREE_COL_TYPE)
        type_column.resizable = true
        content_tree.append_column(type_column)

        id_renderer = Gtk::CellRendererText.new
        id_column = Gtk::TreeViewColumn.new('ID', id_renderer, markup: TREE_COL_ID)
        id_column.resizable = true
        content_tree.append_column(id_column)

        content_tree.selection.signal_connect('changed') do |selection|
          on_tree_selection_changed(selection)
        end
      end

      def setup_properties_view
        @properties_store = Gtk::ListStore.new(String, String)
        properties_view.model = @properties_store

        key_renderer = Gtk::CellRendererText.new
        key_column = Gtk::TreeViewColumn.new('Property', key_renderer, markup: PROP_COL_KEY)
        key_column.resizable = true
        key_column.min_width = 150
        properties_view.append_column(key_column)

        value_renderer = Gtk::CellRendererText.new
        value_column = Gtk::TreeViewColumn.new('Value', value_renderer, markup: PROP_COL_VALUE)
        value_column.resizable = true
        value_column.expand = true
        properties_view.append_column(value_column)
      end

      def setup_file_list_selection
        file_list.signal_connect('row-selected') do |_widget, row|
          next unless row

          index = row.index
          load_file(@files[index]) if index < @files.size
        end
      end

      def load_file(path)
        @tree_store.clear
        @tree_nodes.clear
        @properties_store.clear

        model = Models::IMG4::File.load(path)
        tree = model.to_tree
        populate_tree(tree, nil)
        content_tree.expand_all
      rescue StandardError => e
        @tree_store.clear
        @tree_nodes.clear
        iter = @tree_store.append(nil)
        iter[TREE_COL_NAME] = "Error loading file: #{e.message}"
        iter[TREE_COL_TYPE] = ''
        iter[TREE_COL_ID]   = ''
        idx = @tree_nodes.size
        @tree_nodes << { name: e.message, type: nil, id: nil, properties: {} }
        iter[TREE_COL_IDX] = idx
      end

      def ansi_to_pango(ansi)
        output = String.new
        output << "<span font='Monospace'>"
        scanner = StringScanner.new(ansi.gsub('<', '&lt;'))
        until scanner.eos?
          output << if scanner.scan(/\e\[\d;(3[0-7]|90|1)m/)
                      %(<span foreground="#{COLOR[scanner[1]]}">)
                    elsif scanner.scan("\e[0m")
                      %(</span>)
                    else
                      scanner.scan(/./m)
                    end
        end
        output << '</span>'
        output
      end

      def populate_tree(node, parent_iter)
        case node
        when Helpers::TreeNode
          iter = @tree_store.append(parent_iter)
          iter[TREE_COL_NAME] = ansi_to_pango(node.name.to_s)
          iter[TREE_COL_TYPE] = node.type.to_s
          iter[TREE_COL_ID]   = node.id.to_s

          idx = @tree_nodes.size
          @tree_nodes << {
            name: ansi_to_pango(node.name.to_s),
            type: node.type,
            id: node.id,
            properties: node.properties || {}
          }
          iter[TREE_COL_IDX] = idx

          node.children.each { |child| populate_tree(child, iter) }
        when Helpers::LeafNode
          iter = @tree_store.append(parent_iter)
          display = node.key_value? ? "#{node.key}: #{ansi_to_pango(node.value.to_s)}" : ansi_to_pango(node.value.to_s)
          iter[TREE_COL_NAME] = display
          iter[TREE_COL_TYPE] = 'leaf'
          iter[TREE_COL_ID]   = ''

          idx = @tree_nodes.size
          props = {}
          props['key'] = node.key if node.key
          props['value'] = ansi_to_pango(node.value.to_s)
          @tree_nodes << { name: display, type: 'leaf', id: nil, properties: props }
          iter[TREE_COL_IDX] = idx
        end
      end

      def on_tree_selection_changed(selection)
        @properties_store.clear
        iter = selection.selected
        return unless iter

        idx = iter[TREE_COL_IDX]
        node_data = @tree_nodes[idx]
        return unless node_data

        # Add built-in attributes
        add_property('Name', node_data[:name].to_s)
        add_property('Type', node_data[:type].to_s) if node_data[:type] && !node_data[:type].to_s.empty?
        add_property('ID', node_data[:id].to_s) if node_data[:id] && !node_data[:id].to_s.empty?

        # Add custom properties
        node_data[:properties].each do |key, value|
          add_property(ansi_to_pango(key.to_s), ansi_to_pango(value.to_s))
        end
      end

      def add_property(key, value)
        iter = @properties_store.append
        iter[PROP_COL_KEY]   = key
        iter[PROP_COL_VALUE] = value
      end

      def strip_ansi(str)
        str.gsub(/\e\[[0-9;]*m/, '')
      end
    end
  end
end
