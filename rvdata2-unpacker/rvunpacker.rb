
# region https://www.gamedev.net/forums/topic/646333-rpg-maker-vx-ace-data-conversion-utility/

# region psych_mods.rb

=begin
This file contains significant portions of Psych 2.0.0 to modify behavior and to fix
bugs. The license follows:

Copyright 2009 Aaron Patterson, et al.

Permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files (the 'Software'), to deal in the Software
without restriction, including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software, and to permit
persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
=end

gem 'psych', '2.0.0'
require 'psych'

if Psych::VERSION == '2.0.0'
  # Psych bugs:
  #
  # 1) Psych has a bug where it stores an anchor to the YAML for an object, but indexes
  # the reference by object_id. This doesn't keep the object alive, so if it gets garbage
  # collected, Ruby might generate an object with the same object_id and try to generate a
  # reference to the stored anchor. This monkey-patches the Registrar to keep the object
  # alive so incorrect references aren't generated. The bug is also present in Psych 1.3.4
  # but there isn't a convenient way to patch that.
  #
  # 2) Psych also doesn't create references and anchors for classes that implement
  # encode_with. This modifies dump_coder to handle that situation.
  #
  # Added two options:
  # :sort - sort hashes and instance variables for objects
  # :flow_classes - array of class types that will automatically emit with flow style
  #                 rather than block style
  module Psych
    module Visitors
      class YAMLTree < Psych::Visitors::Visitor
        class Registrar
          old_initialize = self.instance_method(:initialize)
          define_method(:initialize) do
            old_initialize.bind(self).call
            @obj_to_obj  = {}
          end

          old_register = self.instance_method(:register)
          define_method(:register) do |target, node|
            old_register.bind(self).call(target, node)
            @obj_to_obj[target.object_id] = target
          end
        end

        remove_method(:visit_Hash)
        def visit_Hash o
          tag      = o.class == ::Hash ? nil : "!ruby/hash:#{o.class}"
          implicit = !tag

          register(o, @emitter.start_mapping(nil, tag, implicit, Nodes::Mapping::BLOCK))

          keys = o.keys
          keys = keys.sort if @options[:sort]
          keys.each do |k|
            accept k
            accept o[k]
          end

          @emitter.end_mapping
        end

        remove_method(:visit_Object)
        def visit_Object o
          tag = Psych.dump_tags[o.class]
          unless tag
            klass = o.class == Object ? nil : o.class.name
            tag   = ['!ruby/object', klass].compact.join(':')
          end

          if @options[:flow_classes] && @options[:flow_classes].include?(o.class)
            style = Nodes::Mapping::FLOW
          else
            style = Nodes::Mapping::BLOCK
          end

          map = @emitter.start_mapping(nil, tag, false, style)
          register(o, map)

          dump_ivars o
          @emitter.end_mapping
        end

        remove_method(:dump_coder)
        def dump_coder o
          @coders << o
          tag = Psych.dump_tags[o.class]
          unless tag
            klass = o.class == Object ? nil : o.class.name
            tag   = ['!ruby/object', klass].compact.join(':')
          end

          c = Psych::Coder.new(tag)
          o.encode_with(c)
          register o, emit_coder(c)
        end

        remove_method(:dump_ivars)
        def dump_ivars target
          ivars = find_ivars target
          ivars = ivars.sort() if @options[:sort]

          ivars.each do |iv|
            @emitter.scalar("#{iv.to_s.sub(/^@/, '')}", nil, nil, true, false, Nodes::Scalar::ANY)
            accept target.instance_variable_get(iv)
          end
        end

      end
    end
  end
else
  warn "Warning: Psych 2.0.0 not detected" if $VERBOSE
end

# endregion

# region RGSS.rb

=begin
Copyright (c) 2013 Howard Jeng

Permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files (the "Software"), to deal in the Software
without restriction, including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
=end

require 'scanf'

class Table
  def initialize(bytes)
    @dim, @x, @y, @z, items, *@data = bytes.unpack('L5 S*')
    raise "Size mismatch loading Table from data" unless items == @data.length
    raise "Size mismatch loading Table from data" unless @x * @y * @z == items
  end

  MAX_ROW_LENGTH = 20

  def encode_with(coder)
    coder.style = Psych::Nodes::Mapping::BLOCK

    coder['dim'] = @dim
    coder['x'] = @x
    coder['y'] = @y
    coder['z'] = @z

    if @x * @y * @z > 0
      stride = @x < 2 ? (@y < 2 ? @z : @y) : @x
      rows = @data.each_slice(stride).to_a
      if MAX_ROW_LENGTH != -1 && stride > MAX_ROW_LENGTH
        block_length = (stride + MAX_ROW_LENGTH - 1) / MAX_ROW_LENGTH
        row_length = (stride + block_length - 1) / block_length
        rows = rows.collect{|x| x.each_slice(row_length).to_a}.flatten(1)
      end
      rows = rows.collect{|x| x.collect{|y| "%04x" % y}.join(" ")}
      coder['data'] = rows
    else
      coder['data'] = []
    end
  end

  def init_with(coder)
    @dim = coder['dim']
    @x = coder['x']
    @y = coder['y']
    @z = coder['z']
    @data = coder['data'].collect{|x| x.split(" ").collect{|y| y.hex}}.flatten
    items = @x * @y * @z
    raise "Size mismatch loading Table from YAML" unless items == @data.length
  end

  def _dump(*ignored)
    return [@dim, @x, @y, @z, @x * @y * @z, *@data].pack('L5 S*')
  end

  def self._load(bytes)
    Table.new(bytes)
  end
end

class Color
  def initialize(bytes)
    @r, @g, @b, @a = *bytes.unpack('D4')
  end

  def _dump(*ignored)
    return [@r, @g, @b, @a].pack('D4')
  end

  def self._load(bytes)
    Color.new(bytes)
  end
end

class Tone
  def initialize(bytes)
    @r, @g, @b, @a = *bytes.unpack('D4')
  end

  def _dump(*ignored)
    return [@r, @g, @b, @a].pack('D4')
  end

  def self._load(bytes)
    Tone.new(bytes)
  end
end

class Rect
  def initialize(bytes)
    @x, @y, @width, @height = *bytes.unpack('i4')
  end

  def _dump(*ignored)
    return [@x, @y, @width, @height].pack('i4')
  end

  def self._load(bytes)
    Rect.new(bytes)
  end
end

def remove_defined_method(scope, name)
  scope.send(:remove_method, name) if scope.instance_methods(false).include?(name)
end

def reset_method(scope, name, method)
  remove_defined_method(scope, name)
  scope.send(:define_method, name, method)
end

def reset_const(scope, sym, value)
  scope.send(:remove_const, sym) if scope.const_defined?(sym)
  scope.send(:const_set, sym, value)
end

def array_to_hash(arr, &block)
  h = {}
  arr.each_with_index do |val, index|
    r = block_given? ? block.call(val) : val
    h[index] = r unless r.nil?
  end
  if arr.length > 0
    last = arr.length - 1
    h[last] = nil unless h.has_key?(last)
  end
  return h
end

def hash_to_array(hash)
  arr = []
  hash.each do |k, v|
    arr[k] = v
  end
  return arr
end

module BasicCoder
  def encode_with(coder)
    ivars.each do |var|
      name = var.to_s.sub(/^@/, '')
      value = instance_variable_get(var)
      coder[name] = encode(name, value)
    end
  end

  def encode(name, value)
    return value
  end

  def init_with(coder)
    coder.map.each do |key, value|
      sym = "@#{key}".to_sym
      instance_variable_set(sym, decode(key, value))
    end
  end

  def decode(name, value)
    return value
  end

  def ivars
    return instance_variables
  end

  INCLUDED_CLASSES = []
  def self.included(mod)
    INCLUDED_CLASSES.push(mod)
  end

  def self.set_ivars_methods(version)
    INCLUDED_CLASSES.each do |c|
      if version == :ace
        reset_method(c, :ivars, ->{
          return instance_variables
        })
      else
        reset_method(c, :ivars, ->{
          return instance_variables.sort
        })
      end
    end
  end
end

class Game_Switches
  include BasicCoder

  def encode(name, value)
    return array_to_hash(value)
  end

  def decode(name, value)
    return hash_to_array(value)
  end
end

class Game_Variables
  include BasicCoder

  def encode(name, value)
    return array_to_hash(value)
  end

  def decode(name, value)
    return hash_to_array(value)
  end
end

class Game_SelfSwitches
  include BasicCoder

  def encode(name, value)
    return Hash[value.collect {|pair|
      key, value = pair
      next ["%03d %03d %s" % key, value]
    }]
  end

  def decode(name, value)
    return Hash[value.collect {|pair|
      key, value = pair
      next [key.scanf("%d %d %s"), value]
    }]
  end
end

class Game_System
  include BasicCoder

  def encode(name, value)
    if name == 'version_id'
      return map_version(value)
    else
      return value
    end
  end
end

module RPG
  class System
    include BasicCoder
    HASHED_VARS = ['variables', 'switches']

    def encode(name, value)
      if HASHED_VARS.include?(name)
        return array_to_hash(value) {|val| reduce_string(val)}
      elsif name == 'version_id'
        return map_version(value)
      else
        return value
      end
    end

    def decode(name, value)
      if HASHED_VARS.include?(name)
        return hash_to_array(value)
      else
        return value
      end
    end
  end

  class EventCommand
    def encode_with(coder)
      raise 'Unexpected number of instance variables' if instance_variables.length != 3
      clean

      case @code
      when MOVE_LIST_CODE # move list
        coder.style = Psych::Nodes::Mapping::BLOCK
      else
        coder.style = Psych::Nodes::Mapping::FLOW
      end
      coder['i'], coder['c'], coder['p'] = @indent, @code, @parameters
    end

    def init_with(coder)
      @indent, @code, @parameters = coder['i'], coder['c'], coder['p']
    end
  end
end

module RGSS
  # creates an empty class in a potentially nested scope
  def self.process(root, name, *args)
    if args.length > 0
      process(root.const_get(name), *args)
    else
      root.const_set(name, Class.new) unless root.const_defined?(name, false)
    end
  end

  # other classes that don't need definitions
  [ # RGSS data structures
    [:RPG, :Actor], [:RPG, :Animation], [:RPG, :Animation, :Frame],
    [:RPG, :Animation, :Timing], [:RPG, :Area], [:RPG, :Armor], [:RPG, :AudioFile],
    [:RPG, :BaseItem], [:RPG, :BaseItem, :Feature], [:RPG, :BGM], [:RPG, :BGS],
    [:RPG, :Class], [:RPG, :Class, :Learning], [:RPG, :CommonEvent], [:RPG, :Enemy],
    [:RPG, :Enemy, :Action], [:RPG, :Enemy, :DropItem], [:RPG, :EquipItem],
    [:RPG, :Event], [:RPG, :Event, :Page], [:RPG, :Event, :Page, :Condition],
    [:RPG, :Event, :Page, :Graphic], [:RPG, :Item], [:RPG, :Map],
    [:RPG, :Map, :Encounter], [:RPG, :MapInfo], [:RPG, :ME], [:RPG, :MoveCommand],
    [:RPG, :MoveRoute], [:RPG, :SE], [:RPG, :Skill], [:RPG, :State],
    [:RPG, :System, :Terms], [:RPG, :System, :TestBattler], [:RPG, :System, :Vehicle],
    [:RPG, :System, :Words], [:RPG, :Tileset], [:RPG, :Troop], [:RPG, :Troop, :Member],
    [:RPG, :Troop, :Page], [:RPG, :Troop, :Page, :Condition], [:RPG, :UsableItem],
    [:RPG, :UsableItem, :Damage], [:RPG, :UsableItem, :Effect], [:RPG, :Weapon],
    # Script classes serialized in save game files
    [:Game_ActionResult], [:Game_Actor], [:Game_Actors], [:Game_BaseItem],
    [:Game_BattleAction], [:Game_CommonEvent], [:Game_Enemy], [:Game_Event],
    [:Game_Follower], [:Game_Followers], [:Game_Interpreter], [:Game_Map],
    [:Game_Message], [:Game_Party], [:Game_Picture], [:Game_Pictures], [:Game_Player],
    [:Game_System], [:Game_Timer], [:Game_Troop], [:Game_Screen], [:Game_Vehicle],
    [:Interpreter]
  ].each {|x| process(Object, *x)}

  def self.setup_system(version, options)
    # convert variable and switch name arrays to a hash when serialized
    # if round_trip isn't set change version_id to fixed number
    if options[:round_trip]
      iso = ->(val) { return val }
      reset_method(RPG::System, :reduce_string, iso)
      reset_method(RPG::System, :map_version, iso)
      reset_method(Game_System, :map_version, iso)
    else
      reset_method(RPG::System, :reduce_string, ->(str) {
        return nil if str.nil?
        stripped = str.strip
        return stripped.empty? ? nil : stripped
      })
      # These magic numbers should be different. If they are the same, the saved version
      # of the map in save files will be used instead of any updated version of the map
      reset_method(RPG::System, :map_version, ->(ignored) { return 12345678 })
      reset_method(Game_System, :map_version, ->(ignored) { return 87654321 })
    end
  end

  def self.setup_interpreter(version)
    # Game_Interpreter is marshalled differently in VX Ace
    if version == :ace
      reset_method(Game_Interpreter, :marshal_dump, ->{
        return @data
      })
      reset_method(Game_Interpreter, :marshal_load, ->(obj) {
        @data = obj
      })
    else
      remove_defined_method(Game_Interpreter, :marshal_dump)
      remove_defined_method(Game_Interpreter, :marshal_load)
    end
  end

  def self.setup_event_command(version, options)
    # format event commands to flow style for the event codes that aren't move commands
    if options[:round_trip]
      reset_method(RPG::EventCommand, :clean, ->{})
    else
      reset_method(RPG::EventCommand, :clean, ->{
        @parameters[0].rstrip! if @code == 401
      })
    end
    reset_const(RPG::EventCommand, :MOVE_LIST_CODE, version == :xp ? 209 : 205)
  end

  def self.setup_classes(version, options)
    setup_system(version, options)
    setup_interpreter(version)
    setup_event_command(version, options)
    BasicCoder.set_ivars_methods(version)
  end

  FLOW_CLASSES = [Color, Tone, RPG::BGM, RPG::BGS, RPG::MoveCommand, RPG::SE]

  SCRIPTS_BASE = 'Scripts'

  ACE_DATA_EXT = '.rvdata2'
  VX_DATA_EXT  = '.rvdata'
  XP_DATA_EXT  = '.rxdata'
  YAML_EXT     = '.yaml'
  RUBY_EXT     = '.rb'

  def self.get_data_directory(base)
    return File.join(base, 'Data')
  end

  def self.get_yaml_directory(base)
    return File.join(base, 'YAML')
  end

  def self.get_script_directory(base)
    return File.join(base, 'Scripts')
  end
end

# endregion

# region serialize.rb

=begin
Copyright (c) 2013 Howard Jeng

Permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files (the "Software"), to deal in the Software
without restriction, including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
=end

require 'fileutils'
require 'zlib'

module RGSS
  def self.change_extension(file, new_ext)
    return File.basename(file, '.*') + new_ext
  end

  def self.sanitize_filename(filename)
    return filename.gsub(/[^0-9A-Za-z]+/, '_')
  end

  def self.files_with_extension(directory, extension)
    return Dir.entries(directory).select{|file| File.extname(file) == extension}
  end

  def self.inflate(str)
    text = Zlib::Inflate.inflate(str)
    return text.force_encoding("UTF-8")
  end

  def self.deflate(str)
    return Zlib::Deflate.deflate(str, Zlib::BEST_COMPRESSION)
  end


  def self.dump_data_file(file, data, time, options)
    File.open(file, "wb") do |f|
      Marshal.dump(data, f)
    end
    File.utime(time, time, file)
  end

  def self.dump_yaml_file(file, data, time, options)
    File.open(file, "wb") do |f|
      Psych::dump(data, f, options)
    end
    File.utime(time, time, file)
  end

  def self.dump_save(file, data, time, options)
    File.open(file, "wb") do |f|
      data.each do |chunk|
        Marshal.dump(chunk, f)
      end
    end
    File.utime(time, time, file)
  end

  def self.dump_raw_file(file, data, time, options)
    File.open(file, "wb") do |f|
      f.write(data)
    end
    File.utime(time, time, file)
  end

  def self.dump(dumper, file, data, time, options)
    self.method(dumper).call(file, data, time, options)
  rescue
    warn "Exception dumping #{file}"
    raise
  end


  def self.load_data_file(file)
    File.open(file, "rb") do |f|
      return Marshal.load(f)
    end
  end

  def self.load_yaml_file(file)
    File.open(file, "rb") do |f|
      return Psych::load(f)
    end
  end

  def self.load_raw_file(file)
    File.open(file, "rb") do |f|
      return f.read
    end
  end

  def self.load_save(file)
    File.open(file, "rb") do |f|
      data = []
      while not f.eof?
        o = Marshal.load(f)
        data.push(o)
      end
      return data
    end
  end

  def self.load(loader, file)
    return self.method(loader).call(file)
  rescue
    warn "Exception loading #{file}"
    raise
  end


  def self.scripts_to_text(dirs, src, dest, options)
    src_file = File.join(dirs[:data], src)
    dest_file = File.join(dirs[:yaml], dest)
    raise "Missing #{src}" unless File.exist?(src_file)

    script_entries = load(:load_data_file, src_file)
    check_time = !options[:force] && File.exist?(dest_file)
    oldest_time = File.mtime(dest_file) if check_time

    file_map, script_index, script_code = Hash.new(-1), [], {}
    script_entries.each do |script|
      magic_number, script_name, code = script[0], script[1], inflate(script[2])
      script_name.force_encoding("UTF-8")

      if code.length > 0
        filename = script_name.empty? ? 'blank' : sanitize_filename(script_name)
        key = filename.upcase
        value = (file_map[key] += 1)
        actual_filename = filename + (value == 0 ? "" : ".#{value}") + RUBY_EXT
        script_index.push([magic_number, script_name, actual_filename])
        full_filename = File.join(dirs[:script], actual_filename)
        script_code[full_filename] = code
        check_time = false unless File.exist?(full_filename)
        oldest_time = [File.mtime(full_filename), oldest_time].min if check_time
      else
        script_index.push([magic_number, script_name, nil])
      end
    end

    src_time = File.mtime(src_file)
    if check_time && (src_time - 1) < oldest_time
      puts "Skipping scripts to text" if $VERBOSE
    else
      puts "Converting scripts to text" if $VERBOSE
      dump(:dump_yaml_file, dest_file, script_index, src_time, options)
      script_code.each {|file, code| dump(:dump_raw_file, file, code, src_time, options)}
    end
  end

  def self.scripts_to_binary(dirs, src, dest, options)
    src_file = File.join(dirs[:yaml], src)
    dest_file = File.join(dirs[:data], dest)
    raise "Missing #{src}" unless File.exist?(src_file)
    check_time = !options[:force] && File.exist?(dest_file)
    newest_time = File.mtime(src_file) if check_time

    index = load(:load_yaml_file, src_file)
    script_entries = []
    index.each do |entry|
      magic_number, script_name, filename = entry
      code = ''
      if filename
        full_filename = File.join(dirs[:script], filename)
        raise "Missing script file #{filename}" unless File.exist?(full_filename)
        newest_time = [File.mtime(full_filename), newest_time].max if check_time
        code = load(:load_raw_file, full_filename)
      end
      script_entries.push([magic_number, script_name, deflate(code)])
    end
    if check_time && (newest_time - 1) < File.mtime(dest_file)
      puts "Skipping scripts to binary" if $VERBOSE
    else
      puts "Converting scripts to binary" if $VERBOSE
      dump(:dump_data_file, dest_file, script_entries, newest_time, options)
    end
  end

  def self.process_file(file, src_file, dest_file, dest_ext, loader, dumper, options)
    src_time = File.mtime(src_file)
    if !options[:force] && File.exist?(dest_file) && (src_time - 1) < File.mtime(dest_file)
      puts "Skipping #{file}" if $VERBOSE
    else
      puts "Converting #{file} to #{dest_ext}" if $VERBOSE
      data = load(loader, src_file)
      dump(dumper, dest_file, data, src_time, options)
    end
  end

  def self.convert(src, dest, options)
    files = files_with_extension(src[:directory], src[:ext])
    files -= src[:exclude]

    files.each do |file|
      src_file = File.join(src[:directory], file)
      dest_file = File.join(dest[:directory], change_extension(file, dest[:ext]))

      process_file(file, src_file, dest_file, dest[:ext], src[:load_file],
                   dest[:dump_file], options)
    end
  end

  def self.convert_saves(base, src, dest, options)
    save_files = files_with_extension(base, src[:ext])
    save_files.each do |file|
      src_file = File.join(base, file)
      dest_file = File.join(base, change_extension(file, dest[:ext]))

      process_file(file, src_file, dest_file, dest[:ext], src[:load_save],
                   dest[:dump_save], options)
    end
  end

  # [version] one of :ace, :vx, :xp
  # [direction] one of :data_bin_to_text, :data_text_to_bin, :save_bin_to_text,
  #             :save_text_to_bin, :scripts_bin_to_text, :scripts_text_to_bin,
  #             :all_text_to_bin, :all_bin_to_text
  # [directory] directory that project file is in
  # [options] :force - ignores file dates when converting (default false)
  #           :round_trip - create yaml data that matches original marshalled data skips
  #                         data cleanup operations (default false)
  #           :line_width - line width form YAML files, -1 for no line width limit
  #                         (default 130)
  #           :table_width - maximum number of entries per row for table data, -1 for no
  #                          table row limit (default 20)
  def self.serialize(version, direction, directory, options = {})
    raise "#{directory} not found" unless File.exist?(directory)

    setup_classes(version, options)
    options = options.clone()
    options[:sort] = true if [:vx, :xp].include?(version)
    options[:flow_classes] = FLOW_CLASSES
    options[:line_width] ||= 130

    table_width = options[:table_width]
    reset_const(Table, :MAX_ROW_LENGTH, table_width ? table_width : 20)

    base = File.realpath(directory)

    dirs = {
      :base   => base,
      :data   => get_data_directory(base),
      :yaml   => get_yaml_directory(base),
      :script => get_script_directory(base)
    }

    dirs.values.each do |d|
      FileUtils.mkdir(d) unless File.exist?(d)
    end

    exts = {
      :ace => ACE_DATA_EXT,
      :vx  => VX_DATA_EXT,
      :xp  => XP_DATA_EXT
    }

    yaml_scripts = SCRIPTS_BASE + YAML_EXT
    yaml = {
      :directory => dirs[:yaml],
      :exclude   => [yaml_scripts],
      :ext       => YAML_EXT,
      :load_file => :load_yaml_file,
      :dump_file => :dump_yaml_file,
      :load_save => :load_yaml_file,
      :dump_save => :dump_yaml_file
    }

    scripts = SCRIPTS_BASE + exts[version]
    data = {
      :directory => dirs[:data],
      :exclude   => [scripts],
      :ext       => exts[version],
      :load_file => :load_data_file,
      :dump_file => :dump_data_file,
      :load_save => :load_save,
      :dump_save => :dump_save
    }

    case direction
    when :data_bin_to_text
      convert(data, yaml, options)
      scripts_to_text(dirs, scripts, yaml_scripts, options)
    when :data_text_to_bin
      convert(yaml, data, options)
      scripts_to_binary(dirs, yaml_scripts, scripts, options)
    when :save_bin_to_text
      convert_saves(base, data, yaml, options)
    when :save_text_to_bin
      convert_saves(base, yaml, data, options)
    when :scripts_bin_to_text
      scripts_to_text(dirs, scripts, yaml_scripts, options)
    when :scripts_text_to_bin
      scripts_to_binary(dirs, yaml_scripts, scripts, options)
    when :all_bin_to_text
      convert(data, yaml, options)
      scripts_to_text(dirs, scripts, yaml_scripts, options)
      convert_saves(base, data, yaml, options)
    when :all_text_to_bin
      convert(yaml, data, options)
      scripts_to_binary(dirs, yaml_scripts, scripts, options)
      convert_saves(base, yaml, data, options)
    else
      raise "Unrecognized direction :#{direction}"
    end
  end
end

# endregion

# endregion

if __FILE__ == $0
  options = { :force => false, :line_width => -1, :table_width => -1 }
  action = (ARGV[0] || "decode").downcase
  direction = :scripts_bin_to_text
  if action == "encode"
    direction = :scripts_text_to_bin
  else
    action = "decode"
  end
  project_root = ARGV[1] || "."
  puts "#{action.chop.capitalize}ing Scripts.rvdata2 in [#{project_root}] ..."
  RGSS.serialize(:ace, direction, project_root, options)
  # puts "Done, press any key to exit."
  # STDIN.getc
end