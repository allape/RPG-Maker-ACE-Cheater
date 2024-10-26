# RPG Maker VX Ace Cheater

# How to Patch on Windows

## Preparing

- Do NOT run patch under a path that contains non-english characters.
    - `rvunpacker.exe` will fail with a path contains Japanese characters on `Windows 10` with Japanese encoding.

## Auto

- Download `RPG-Maker-ACE-Cheater-Patcher.exe` from https://github.com/allape/RPG-Maker-ACE-Cheater/releases, and put it
  in
  the game folder.
- Double click `RPG-Maker-ACE-Cheater-Patcher.exe` to patch the game.

## Manually

- Preparing
    - Open game folder, and make sure every command executes at the root of the game folder.
    - Open a terminal/cmd/powershell window in game folder by `Shift + Mouse Right Click` -> `Open in Terminal`.
    - If `rvunpacker.exe` is untrusted, you may need to download Ruby DevKit then run with
      ```shell
      ruby rvdata2-unpacker/rvunpacker.rb decode .
      ```
        - See [README.md](rvdata2-unpacker/README.md) for more details.
- Use [RPGMakerDecrypter-cli.exe](https://github.com/uuksu/RPGMakerDecrypter) to unpack `Game.rgss3a`.
    - Download `RPGMakerDecrypter-cli.exe`
      from [https://github.com/uuksu/RPGMakerDecrypter/releases](https://github.com/uuksu/RPGMakerDecrypter/releases).
    - Run
      ```shell
      RPGMakerDecrypter-cli.exe Game.rgss3a
      move Game.rgss3a Game.rgss3a~
      ```
- Use [rvunpacker.exe](rvdata2-unpacker/rvunpacker.exe) to unpack `Data/Scripts.rvdata2`.
    - Download this repo and copy [rvdata2-unpacker/rvunpacker.exe](rvdata2-unpacker/rvunpacker.exe) to the
      game folder.
    - Run
      ```shell
      rvunpacker.exe decode .
      ```
- Copy everything in [AsCheater.rb](AsCheater.rb) to the beginning of `Scripts/Main.rb`.
    - Snippet:
      ```ruby
      blah blah blah
      
            end
          end
        end
      end
      
      #==============================================================================
      # ■ Main
      #------------------------------------------------------------------------------
      # 　モジュールとクラスの定義が終わった後に実行される処理です。
      #==============================================================================
      
      blah blah blah
      ```
- Open `Scripts/Scene_Base.rb`:
    - Put code `AsCheater.update` after line `def update`. For example:
      ```ruby
      # other codes...
      def update
        AsCheater.update
        # other codes...
        update_basic
        # other codes...
      end
      # other codes...
      ```
- Use [rvunpacker.exe](rvdata2-unpacker/rvunpacker.exe) to repack `Scripts` and `YAML` back to `Data/Scripts.rvdata2`.
    - Run
      ```shell
      rvunpacker.exe encode .
      ```
- Then the game is patched.

# Usage

- `` ` ``: Save game at slot 2
- `1`: Cure all alias
- `2`: Make all enemies one
- `3`: Kill all enemies
- `4`: Reserved
- `5`: Reserved
- `6`: Cure all enemies
- `7`: Make all alias one
- `8`: Reserved
- `9`: Reserved
- `0`: Gain gold 10K
- `-`: Decrease the amount of current selected item by 1, by 10 if `Shift` is pressed
    - Should open `Menu` -> `Item List` first, and select the corresponding item
- `+`: Increase the amount of current selected item by 1, by 10 if `Shift` is pressed
    - Should open `Menu` -> `Item List` first, and select the corresponding item
- `[`: Save current position
- `]`: Load saved position
- `q`: Execute `asac.q.rb` script file in the game root folder
  - If script file contains runtime error, the game will crash
- `w`: Execute `asac.w.rb` script file in the game root folder
  - If script file contains runtime error, the game will crash
- `e`: Execute `asac.e.rb` script file in the game root folder
  - If script file contains runtime error, the game will crash
- `r`: Reload loaded `asac.*.rb` script files

# Dev

- Download `RPGMakerDecrypter-cli.exe` from https://github.com/uuksu/RPGMakerDecrypter/releases, and put it in root of
  project along
  with [main.go](main.go).
- Run [build.sh](build.sh) or [build.bat](build.bat) to build the patcher.

# Credits

- [RPGMakerDecrypter](https://github.com/uuksu/RPGMakerDecrypter)
- Hime_AllKey
- https://www.gamedev.net/forums/topic/646333-rpg-maker-vx-ace-data-conversion-utility/
