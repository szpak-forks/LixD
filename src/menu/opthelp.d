module menu.opthelp;

/* Helper classes for the options dialogue.
 *
 * Subclasses of Option: Wraps the GUI elements through which an option is set,
 * and points to the value T that is used by the game and written to file.
 *
 * Important! Geom must be the first argument of any constructor of a subclass
 * of Option. Otherwise, OptionFactory will choke on that type.
 *
 * OptionFactory: computes the geom, incrementing the y position after each
 * factory(), and otherwise passes arguments to the Option subclass
 * constructors.
 */

import std.algorithm;
import std.conv;
import std.string; // strip

import graphic.gralib;
import gui;
import lix.enums;

enum spaceGuiTextX =  10f;
enum mostButtonsXl = 120f;
enum keyButtonXl   =  70f;

abstract class Option : Element
{
    private Label _desc; // may be null

    abstract void loadValue();
    abstract void saveValue(); // can't be const

    this(Geom g, Label d = null)
    {
        super(g);
        _desc = d;
        if (_desc)
            addChild(_desc);
    }
}

struct OptionFactory {
    float x, y, xl, yl = 20f;
    float incrementY   = 30f;
    Geom.From from     = From.TOP_LEFT;

    Option factory(T, Args...)(Args argsToForward)
    {
        auto ret = new T(new Geom(x, y, xl, yl, from), argsToForward);
        y += incrementY;
        return ret;
    }
}



class BoolOption : Option
{
    private Checkbox _checkbox;
    private bool*    _target;

    this(Geom g, string cap, bool* t)
    {
        assert (t);
        _checkbox = new Checkbox(new Geom(0, 0, 20, 20));
        super(g, new Label(new Geom(30, 0, g.xlg - 30, g.yl), cap));
        addChild(_checkbox);
        _target = t;
    }

    override void loadValue() { _checkbox.checked = *_target; }
    override void saveValue() { *_target = _checkbox.checked; }
}



class TextOption : Option
{
    private Texttype _texttype;
    private string*  _target;

    this(Geom g, string cap, string* t)
    {
        assert (t);
        _texttype = new Texttype(new Geom(0, 0, mostButtonsXl, 20));
        super(g, new Label(new Geom(mostButtonsXl + spaceGuiTextX, 0,
                            g.xlg - mostButtonsXl + spaceGuiTextX, g.yl),
                            cap));
        addChild(_texttype);
        _target = t;
    }

    override void loadValue() { _texttype.text = *_target; }
    override void saveValue() { *_target = _texttype.text.strip; }
}



class HotkeyOption : Option
{
    private KeyButton _keyb;
    private int*      _target;

    this(Geom g, string cap, int* t)
    {
        assert (t);
        _keyb = new KeyButton(new Geom(0, 0, keyButtonXl, 20));
        super(g, new Label(new Geom(keyButtonXl + spaceGuiTextX, 0,
                            g.xlg - keyButtonXl + spaceGuiTextX, g.yl), cap));
        addChild(_keyb);
        _target = t;
    }

    override void loadValue() { _keyb.scancode = *_target; }
    override void saveValue() { *_target = _keyb.scancode; }
}

class SkillHotkeyOption : Option
{
    private CutbitElement _cb;
    private KeyButton _keyb;
    private int* _target;

    this(Geom g, Ac ac, int* t)
    {
        super(g);
        assert (t);
        _keyb = new KeyButton(new Geom(0, 0, xlg, 20, From.BOTTOM));
        _cb   = new CutbitElement(new Geom(0, 0, xlg, ylg-20, From.TOP),
                                  Style.garden.getSkillButtonIcon);
        _cb.xf = ac;
        addChildren(_cb, _keyb);
        _target = t;
    }

    override void loadValue() { _keyb.scancode = *_target; }
    override void saveValue() { *_target = _keyb.scancode; }
}



class NumPickOption : Option
{
    private NumPick _num;
    private int*    _target;

    // hack, to enable immediate updates of the GUI menu colors
    public @property inout(NumPick) num() inout { return _num; }

    this(Geom g, NumPickConfig cfg, string cap, int* t)
    {
        assert (t);
        _num = new NumPick(new Geom(0, 0, mostButtonsXl, 20), cfg);
        super(g, new Label(new Geom(mostButtonsXl + spaceGuiTextX, 0,
                            g.xlg - mostButtonsXl + spaceGuiTextX, g.yl),
                            cap));
        addChild(_num);
        _target = t;
    }

    override void loadValue() { _num.number = *_target; }
    override void saveValue() { *_target = _num.number; }
}



alias ResolutionOption = ManyNumbersOption!2;

class ManyNumbersOption (int fields) : Option
    if (fields >= 1) {

private:

    Texttype[fields] _texttype;
    int*    [fields] _target;

public:

    this(Geom g, string cap, int*[fields] targets...)
    {
        super(g, new Label(new Geom(mostButtonsXl + spaceGuiTextX, 0,
                            g.xlg - mostButtonsXl + spaceGuiTextX, g.yl),
                            cap));
        foreach (i; 0 .. fields) {
            _texttype[i] = new Texttype(new Geom(
                i * mostButtonsXl/fields, 0, mostButtonsXl/fields, 20));
            _texttype[i].allowedChars = Texttype.AllowedChars.digits;
            addChild(_texttype[i]);
            _target[i] = targets[i];
        }
    }

    override void loadValue()
    {
        foreach (i; 0 .. fields)
            _texttype[i].text = to!string(*_target[i]);
    }

    override void saveValue()
    {
        foreach (i; 0 .. fields)
            *_target[i] = _texttype[i].number;
    }
}
