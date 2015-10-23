module graphic.gadget.openfor;

/* GadgetCanBeOpen : Gadget      has the method isOpenFor(Tribe).
 * Water       : GadgetCanBeOpen is a permanent trap, water or fire.
 * Triggerable : GadgetCanBeOpen is a cooldown trap or cooldown flinger.
 * Trampoline  : GadgetCanBeOpen is permanently active, anims on trigger.
 */

import basics.help;
import game.tribe;
import graphic.gadget;
import graphic.torbit;
import level.level;
import level.tile;
import hardware.sound;

public alias Water     = PermanentlyOpen;
public alias Fire      = PermanentlyOpen;
public alias FlingPerm = PermanentlyOpen;

public alias TrapTrig  = Triggerable;
public alias FlingTrig = Triggerable;

class GadgetCanBeOpen : Gadget {

public:

    mixin (StandardGadgetCtor!());

    this(typeof (this) rhs)
    {
        super(rhs);
        _tribes     = rhs._tribes;
        _startAnim = rhs._startAnim;
    }

    abstract override typeof (this) clone();

    @property bool startAnim() const { return _startAnim;     }
    @property bool startAnim(bool b) { return _startAnim = b; }

    bool isOpenFor(Tribe t) { return ! hasTribe(t); }

    final void addTribe(Tribe t)
    {
        if (! hasTribe(t))
            _tribes ~= t;
    }

    override void animate()
    {
        if (xf != 0 || _startAnim)
            super.animate();
        _startAnim = false;
        _tribes = null;
    }

private:

    Tribe[] _tribes;
    bool _startAnim;

    final protected bool hasTribe(const(Tribe) t) const
    {
        foreach (tribeInVec; _tribes)
            if (t is tribeInVec)
                return false;
        return true;
    }

}
// end class GadgetCanBeOpen



private class PermanentlyOpen : GadgetCanBeOpen {

    mixin (StandardGadgetCtor!());
    mixin (CloneableTrivialOverride!());

    override bool isOpenFor(Tribe t)
    {
        return true;
    }

    override void animate()
    {
        Gadget.animate(); // the constantly looping animation
    }

    override @property Sound sound()
    {
        return tile.type != TileType.WATER ? Sound.NOTHING // perm. flinger
             : tile.subtype == 0           ? Sound.WATER
             :                               Sound.FIRE;
    }

}
// end class PermanentAnim



private class Triggerable : GadgetCanBeOpen {

    mixin (StandardGadgetCtor!());
    mixin (CloneableTrivialOverride!());

    override bool isOpenFor(Tribe t)
    {
        return xf == 0 && ! hasTribe(t);
    }

}
// end class Triggerable



class Trampoline : GadgetCanBeOpen {

    mixin (StandardGadgetCtor!());
    mixin (CloneableTrivialOverride!());

    override bool isOpenFor(Tribe t)
    {
        // trampolines are always active, even if they animate only on demand
        return true;
    }

}
// end class Trampoline
