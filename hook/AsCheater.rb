# Should patch this module at the beginning of Main.rb
module AsCheater
  # Hime_AllKey
  DOWN_STATE_MASK = (0x8 << 0x04)

  # noinspection RubyResolve
  GetKeyboardState = Win32API.new("user32.dll", "GetKeyboardState",  "I", "I")
  # noinspection RubyResolve
  MessageBox = Win32API.new("user32", "MessageBox", %w[i p p i], "i")
  # MessageBox.call(0, "message", "title", 0)

  # noinspection RubyResolve
  @state    = DL::CPtr.new(DL.malloc(256), 256)
  @debounce = Time.now.to_f

  def self.pressed(key_code)
    return @state[key_code] & DOWN_STATE_MASK == DOWN_STATE_MASK
  end

  def self.update
    now = Time.now.to_f
    if now - @debounce < 0.1
      return
    end

    @debounce = now
    GetKeyboardState.call(@state.to_i)

    # https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes

    if pressed(0xC0)
      if $game_party.all_members.length == 0
        Sound.play_cancel
        return
      end
      DataManager.save_game_without_rescue(1)
      Sound.play_ok
    end

    if pressed(0x31)
      $game_party.all_members.each do |actor|
        unless actor.alive?
          return
        end
        actor.recover_all
      end
      Sound.play_ok
    end

    if pressed(0x32)
      $game_troop.alive_members.each do |enemy|
        enemy.hp = 0
      end
      Sound.play_ok
    end

    if pressed(0xBD)
      Sound.play_cancel
    end

    if pressed(0x30)
      $game_party.gain_gold(10000)
      Sound.play_ok
    end
  end
end

# Should patch `AsCheater.update` to update function in Scene_Base.rb
class Scene_Base
  # other codes...
  def update
    # other codes...
    AsCheater.update
    # other codes...
  end
  # other codes...
end
