# RPG Maker VX Ace Cheater

Prototyping...

# How to Patch on Windows

- Preparing
    - Open game folder, and make sure every command executes at the root of the game folder.
    - Open a terminal/cmd/powershell window in game folder by `Shift + Mouse Right Click` -> `Open in Terminal`.
    - If `rvunpacker.exe` is untrusted, you may need to download Ruby DevKit then run with
      ```ruby
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
- `2`: Kill all enemies
- `0`: Gain gold 10K
- `-`: Reduce the amount of current selected item by 1
    - Should open `Menu` -> `Item List` first, and select the corresponding item
- `+`: Increase the amount of current selected item by 1
    - Should open `Menu` -> `Item List` first, and select the corresponding item
- `[`: Save current position
- `]`: Load saved position

# Credits

- [RPGMakerDecrypter](https://github.com/uuksu/RPGMakerDecrypter)
- Hime_AllKey
- https://www.gamedev.net/forums/topic/646333-rpg-maker-vx-ace-data-conversion-utility/
