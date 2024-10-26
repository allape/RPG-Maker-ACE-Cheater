module AsCheater
  # Hime_AllKey
  DOWN_STATE_MASK = (0x8 << 0x04)

  # noinspection RubyResolve
  GetKeyboardState = Win32API.new("user32.dll", "GetKeyboardState", "I", "I")
  # noinspection RubyResolve
  MessageBox = Win32API.new("user32", "MessageBox", %w[i p p i], "i")
  # MessageBox.call(0, "message", "title", 0)

  LoadableASACIndexes = %w[q w e]

  # noinspection RubyResolve
  @state = DL::CPtr.new(DL.malloc(256), 256)
  @debounce = Time.now.to_f

  @saved_map_id = -1
  @saved_x = 0
  @saved_y = 0

  @loaded_asac_files = {}

  def self.load_asac_files
    LoadableASACIndexes.each do |index|
      filename = "asac." + index + ".rb"
      if File.exist?(filename)
        @loaded_asac_files[index] = File.read(filename)
      end
    end
  end

  def self.eval_asac_file(index)
    if @loaded_asac_files[index]
      eval(@loaded_asac_files[index])
      Sound.play_ok
    else
      Sound.play_buzzer
    end
  end

  def self.pressed(key_code)
    return @state[key_code] & DOWN_STATE_MASK == DOWN_STATE_MASK
  end

  def self.is_shift_key_pressed
    return (@state[0xA0] & DOWN_STATE_MASK == DOWN_STATE_MASK) || (@state[0xA1] & DOWN_STATE_MASK == DOWN_STATE_MASK)
  end

  def self.gain_item(amount)
    if SceneManager.scene and SceneManager.scene.is_a?(Scene_ItemBase)
      if SceneManager.scene.item
        $game_party.gain_item(SceneManager.scene.item, amount)
        Sound.play_ok
      else
        Sound.play_buzzer
      end
    else
      Sound.play_buzzer
    end
  end

  def self.update
    now = Time.now.to_f
    if now - @debounce < 0.1
      return
    end

    @debounce = now
    GetKeyboardState.call(@state.to_i)

    # https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes

    if pressed(0xC0) # ` > save at slot 2
      save_index = 1
      if $game_party.all_members.length == 0
        Sound.play_buzzer
        return
      end
      if DataManager.respond_to?(:save_game_with_preview)
        DataManager.save_game_with_preview(save_index)
      else
        DataManager.save_game_without_rescue(save_index)
      end
      Sound.play_ok
    end

    if pressed(0x31) # 1 > cure all alias
      $game_party.all_members.each do |actor|
        actor.recover_all
      end
      Sound.play_ok
    end

    if pressed(0x32) # 2 > make all enemies one
      $game_troop.alive_members.each do |enemy|
        enemy.hp = 1 # may cause crash
      end
      Sound.play_ok
    end

    if pressed(0x33) # 3 > kill all enemies
      $game_troop.alive_members.each do |enemy|
        enemy.hp = 0
      end
      Sound.play_ok
    end

    if pressed(0x36) # 6 > cure all enemies
      $game_troop.members.each do |enemy|
        enemy.recover_all
      end
      Sound.play_ok
    end

    if pressed(0x37) # 7 > all alias one
      $game_party.all_members.each do |actor|
        unless actor.alive?
          return
        end
        actor.hp = 1
      end
      Sound.play_ok
    end

    if pressed(0x30) # 0 > gain gold 10K
      $game_party.gain_gold(10000)
      Sound.play_ok
    end

    if pressed(0xBD) # - > decrease the amount of selected item
      if is_shift_key_pressed
        gain_item(-10)
      else
        gain_item(-1)
      end
    end

    if pressed(0xBB) # = > increase the amount of selected item
      if is_shift_key_pressed
        gain_item(10)
      else
        gain_item(1)
      end
    end

    if pressed(0xDB) # [ -> Save current position
      @saved_map_id = $game_map.map_id
      @saved_x = $game_player.x
      @saved_y = $game_player.y
      Sound.play_ok
    end

    if pressed(0xDD) # ] -> Load saved position
      if @saved_map_id != -1
        $game_player.reserve_transfer(@saved_map_id, @saved_x, @saved_y, 0)
        Sound.play_ok
      else
        Sound.play_buzzer
      end
    end

    if pressed(0x51) # Q -> Run asac.q.rb
      eval_asac_file('q')
    end

    if pressed(0x57) # W -> Run asac.w.rb
      eval_asac_file('w')
    end

    if pressed(0x45) # E -> Run asac.e.rb
      eval_asac_file('e')
    end

    if pressed(0x52) # R -> Reload all asac files
      load_asac_files
      Sound.play_ok
    end
  end
end

AsCheater.load_asac_files
