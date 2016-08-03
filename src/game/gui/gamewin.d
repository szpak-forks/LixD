module game.gui.gamewin;

import std.algorithm;
import std.typecons; // Rebindable
import std.string; // package class

import basics.user; // hotkeys
import file.filename;
import file.language;
import game.replay;
import gui;
import hardware.keyset;
import hardware.sound;
import level.level;

abstract class GameWindow : Window {
private:
    Label _saveReplayDone;
    Rebindable!(const Replay) _replay;
    Rebindable!(const Level) _level;

protected:
    TextButton _resume;
    TextButton _saveReplay;
    TextButton _restart;
    TextButton _exitGame;

public:
    this(Geom g)               { super(g, Lang.winGameTitle.transl); }
    this(Geom g, string title) { super(g, title); }

    final bool resume()   { return _resume   && _resume.execute;   }
    final bool restart()  { return _restart  && _restart.execute;  }
    final bool exitGame() { return _exitGame && _exitGame.execute; }

protected:
    final void captionSuperElements()
    {
        void oneBut(ref TextButton b, in string cap, in KeySet hk)
        {
            if (! b)
                return;
            b.text   = cap;
            b.hotkey = KeySet(b.hotkey, hk);
            addChild(b);
        }
        oneBut(_resume,     Lang.winGameResume.transl,     keyPause);
        oneBut(_saveReplay, Lang.winGameSaveReplay.transl, keyStateSave);
        oneBut(_restart,    Lang.winGameRestart.transl,    keyRestart);
        oneBut(_exitGame,   Lang.winGameMenu.transl,       keyGameExit);
    }

    final void setReplayAndLevel(
        const(Replay) rep,
        const(Level) lev,
    ) {
        assert (_saveReplay, "instantiate _saveReplay before passing replay");
        assert (rep);
        _replay = rep;
        _level  = lev;
        _saveReplayDone = new Label(new Geom(_saveReplay.geom));
        _saveReplayDone.text = Lang.browserExportImageDone.transl;
        _saveReplayDone.hide();
        _saveReplay.onExecute = () {
            assert (_replay !is null);
            _replay.saveManually(_level);
            hardware.sound.playLoud(Sound.DISKSAVE);
            if (_saveReplayDone) {
                _saveReplay.hide();
                _saveReplayDone.show();
            }
        };
        addChild(_saveReplayDone);
    }
}
