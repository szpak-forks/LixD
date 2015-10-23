module gui.button;

/* A clickable button, can have a hotkey.
 *
 * Two design patterns are supported: a) Event-based callback and b) polling.
 * a) To poll the button, (bool execute() const) during its parent's calc().
 * b) To register a delegate f to be called back, use onExecute(f).
 */

import basics.alleg5; // keyboard enum
import graphic.color;
import gui;
import hardware.keyboard;
import hardware.mouse;

class Button : Element {

    enum WhenToExecute {
        whenMouseRelease, // cold, normal menu buttons
        whenMouseClick, // warm, pause button
        whenMouseHeld, // hot, skill button
        whenMouseClickAllowingRepeats // spawnint, framestepping
    }

    this(Geom g) { super(g); }

    @property int hotkey() const { return _hotkey;     }
    @property int hotkey(int i)  { return _hotkey = i; }

    WhenToExecute whenToExecute;

    // execute is read-only. Derived classes should make their own bool
    // and then override execute().
    @property bool execute() const              { return _execute; }
    @property void onExecute(void delegate() f) { _onExecute = f;  }

    @property bool down() const { return _down; }
    @property bool on  () const { return _on;   }

    @property bool down(in bool b)
    {
        if (_down != b) {
            _down = b;
            reqDraw();
        }
        return _down;
    }

    @property bool on(in bool b)
    {
        if (_on != b) {
            _on = b;
            reqDraw();
        }
        return _on;
    }

    AlCol colorText() { return _on && ! _down ? color.guiTextOn
                                              : color.guiText; }


private:

    int  _hotkey; // default is 0, which is not a key.

    bool _execute;
    bool _down;
    bool _on;

    void delegate() _onExecute;



protected:

override void
calcSelf()
{
    immutable bool mouseHere = isMouseHere();

    if (hidden) {
        _execute = false;
        _down    = false;
    }
    else final switch (whenToExecute) {
    case WhenToExecute.whenMouseRelease:
        down     = mouseHere && mouseHeldLeft;
        _execute = mouseHere && mouseReleaseLeft || _hotkey.keyTapped;
        break;
    case WhenToExecute.whenMouseClick:
        down     = mouseHere && mouseHeldLeft;
        _execute = mouseHere && mouseClickLeft || _hotkey.keyTapped;
        break;
    case WhenToExecute.whenMouseHeld:
        down     = false;
        _execute = mouseHere && mouseHeldLeft || _hotkey.keyTapped;
        break;
    case WhenToExecute.whenMouseClickAllowingRepeats:
        down     = mouseHere && mouseHeldLeft;
        _execute = mouseHere && mouseHeldLongLeft
            || _hotkey.keyTappedAllowingRepeats;
        break;
    }
    if (_onExecute !is null && _execute)
        _onExecute();
}



override void
drawSelf()
{
    // select the colors according to the button's state
    auto c1 = _down ? color.guiDownD : _on ? color.guiOnD : color.guiL;
    auto c2 = _down ? color.guiDownM : _on ? color.guiOnM : color.guiM;
    auto c3 = _down ? color.guiDownL : _on ? color.guiOnL : color.guiD;

    draw3DButton(xs, ys, xls, yls, c1, c2, c3);
}

}
// end class
